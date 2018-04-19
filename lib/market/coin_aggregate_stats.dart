import 'package:flutter/material.dart';

import 'package:flutter_sparkline/flutter_sparkline.dart';
import 'package:trace/flutter_candlesticks.dart';

import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:trace/main.dart';
import 'package:trace/market.dart';
import 'package:trace/market/coin_markets_list.dart';


Map OHLCVWidthOptions = {
  "1h":[["1m", 60, 1, "minute"], ["2m", 30, 2, "minute"], ["3m", 20, 3, "minute"]],
  "6h":[["5m", 72, 5, "minute"], ["10m", 36, 10, "minute"], ["15m", 24, 15, "minute"]],
  "12h":[["10m", 72, 10, "minute"], ["15m", 48, 15, "minute"], ["30m", 24, 30, "minute"]],
  "24h":[["15m", 96, 15, "minute"], ["30m", 48, 30, "minute"], ["1h", 24, 1, "hour"]],
  "3D":[["1h", 72, 1, "hour"], ["2h", 36, 2, "hour"], ["4h", 18, 4, "hour"]],
  "7D":[["2h", 86, 2, "hour"], ["4h", 42, 4, "hour"], ["6h", 28, 6, "hour"]],
  "1M":[["12h", 60, 12, "hour"], ["1D", 30, 1, "day"]],
  "3M":[["1D", 90, 1, "day"], ["2D", 45, 2, "day"], ["3D", 30, 3, "day"]],
  "6M":[["2D", 90, 2, "day"], ["3D", 60, 3, "day"], ["7D", 26, 7, "day"]],
  "1Y":[["7D", 52, 7, "day"], ["14D", 26, 14, "day"]],
};


//TODO: probably figure out a better way to do this
Map generalStats;

List sparkLineData;
List historySparkline;
List historyOHLCVTimeAggregated;

String _high = "0";
String _low = "0";
String _change = "0";

void resetCoinStats() {
  generalStats = null;

  sparkLineData = null;
  historySparkline = null;
  historyOHLCVTimeAggregated = null;

  _high = "0";
  _low = "0";
  _change = "0";
}

class AggregateStats extends StatefulWidget {
  AggregateStats({
    Key key,
    this.snapshot,
    this.currentOHLCVWidthSetting = 1,
    this.historyAmt = "720",
    this.historyAgg = "2",
    this.historyType = "minute",
    this.historyTotal = "24h",
    this.toSym = "USD",
    this.showSparkline = true,
  })  : assert(snapshot != null),
        super(key: key);

  final snapshot;

  final currentOHLCVWidthSetting;

  final showSparkline;

  final historyAmt;
  final historyType;
  final historyTotal;
  final historyAgg;

  final toSym;

  @override
  AggregateStatsState createState() => new AggregateStatsState(
      snapshot: snapshot,
      currentOHLCVWidthSetting: currentOHLCVWidthSetting,
      historyAmt: historyAmt,
      historyAgg: historyAgg,
      historyType: historyType,
      historyTotal: historyTotal,
      toSym: toSym,
      showSparkline: showSparkline,
  );
}

class AggregateStatsState extends State<AggregateStats> {
  AggregateStatsState({
    this.snapshot,
    this.currentOHLCVWidthSetting,
    this.historyAmt ,
    this.historyAgg,
    this.historyType,
    this.historyTotal,
    this.toSym,
    this.showSparkline,
  });

  Map snapshot;

  int currentOHLCVWidthSetting;

  bool showSparkline;

  String historyAmt;
  String historyType;
  String historyTotal;
  String historyAgg;

  String toSym;

  Map generalStats;

  final ScrollController _scrollController = new ScrollController();

  Future<Null> getGeneralStats() async {
    var response = await http.get(
        Uri.encodeFull("https://api.coinmarketcap.com/v1/ticker/"+ snapshot["id"]),
        headers: {"Accept": "application/json"}
    );
    setState(() {
      generalStats = new JsonDecoder().convert(response.body)[0];
    });
  }

  Future<Null> getHistorySparkLine() async {
    var response = await http.get(
      Uri.encodeFull("https://min-api.cryptocompare.com/data/histo" +historyType
          +"?fsym="+snapshot["symbol"]
          +"&tsym=USD&limit="+(int.parse(historyAmt)-1).toString()
          +"&aggregate="+historyAgg),
      headers: {"Accept": "application/json"}
    );
    setState(() {
      historySparkline = new JsonDecoder().convert(response.body)["Data"];
    });
  }


  Future<Null> getHistoryOHLCV() async {
    var response = await http.get(
        Uri.encodeFull(
            "https://min-api.cryptocompare.com/data/histo"+OHLCVWidthOptions[historyTotal][currentOHLCVWidthSetting][3]+
            "?fsym="+snapshot["symbol"]+
            "&tsym=USD&limit="+(OHLCVWidthOptions[historyTotal][currentOHLCVWidthSetting][1] - 1).toString()+
            "&aggregate="+OHLCVWidthOptions[historyTotal][currentOHLCVWidthSetting][2].toString()
        ),
        headers: {"Accept": "application/json"}
    );
    setState(() {
      historyOHLCVTimeAggregated = new JsonDecoder().convert(response.body)["Data"];
    });
  }

  Future<Null> changeOHLCVWidth(int currentSetting) async {
    currentOHLCVWidthSetting = currentSetting;
    historyOHLCVTimeAggregated = null;
    getHistoryOHLCV();
  }

  void _getHL() {
    num highReturn = -double.infinity;
    num lowReturn = double.infinity;

    for (var i in historySparkline) {
      if (i["high"] > highReturn) {
        highReturn = i["high"].toDouble();
      }
      if (i["low"] < lowReturn) {
        lowReturn = i["low"].toDouble();
      }
    }

    _high = highReturn.toString();
    _low = lowReturn.toString();

    var start = historySparkline[0]["close"] == 0 ? 1 : historySparkline[0]["close"];
    var end = historySparkline.last["close"];

    var changePercent = (end-start)/start*100;

    _change = changePercent.toString().substring(0, changePercent > 0 ? 5 : 6);
  }

  Future<Null> makeSparkLineData() async {
    List<double> returnData = [];

    for (var i in historySparkline) {
      returnData.add(((i["high"]+i["low"])/2));
    }

    setState(() {
      sparkLineData = returnData;
    });
  }

  Future<Null> changeHistory(String type, String amt, String total, String agg) async {
    setState((){
      _high = "0";
      _low = "0";
      _change = "0";

      historyAmt = amt;
      historyType = type;
      historyTotal = total;
      historyAgg = agg;

      sparkLineData = null;
      historyOHLCVTimeAggregated = null;

    });
    getGeneralStats();
    getHistoryOHLCV();
    await getHistorySparkLine();
    _getHL();
    makeSparkLineData();
  }

  void initState() {
    super.initState();
    if (sparkLineData == null) {
      changeHistory(historyType, historyAmt, historyTotal, historyAgg);
    }
    if (historyOHLCVTimeAggregated == null) {
      getHistoryOHLCV();
    }
    if (generalStats == null) {
      getGeneralStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        resizeToAvoidBottomPadding: false,
        body: new RefreshIndicator(
          onRefresh: () => changeHistory(historyType, historyAmt, historyTotal, historyAgg), //TODO: refresh stats carried over from coinmarketcap as well
          child: new Column(
            children: <Widget>[
              new Container(
                padding: const EdgeInsets.only(left: 6.0, right: 6.0, top: 5.0, bottom: 1.0),
                child: new Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    new Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        new Text("Price", style: Theme.of(context).textTheme.body1.apply(color: Theme.of(context).hintColor)),
                        new Text("\$"+ (generalStats != null ? generalStats["price_usd"] : snapshot["price_usd"]).toString(), style: Theme.of(context).textTheme.button.apply(fontSizeFactor: 1.4, color: Theme.of(context).accentColor)),
                      ],
                    ),
                    new Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        new Text("Market Cap", style: Theme.of(context).textTheme.body1.apply(color: Theme.of(context).hintColor)),
                        new Text(numCommaParse((generalStats != null ? generalStats["market_cap_usd"] : snapshot["market_cap_usd"]).toString()), style: Theme.of(context).textTheme.body2.apply(fontSizeFactor: 1.1)),
                      ],
                    ),
                    new Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        new Text("24h Volume", style: Theme.of(context).textTheme.body1.apply(color: Theme.of(context).hintColor)),
                        new Text(numCommaParse((generalStats != null ? generalStats["24h_volume_usd"] : snapshot["24h_volume_usd"]).toString()), style: Theme.of(context).textTheme.body2.apply(fontSizeFactor: 1.1)),
                      ],
                    ),
                  ],
                ),
              ),
              new Row(
                children: <Widget>[
                  new Flexible(
                    child: new Container(
                        color: Theme.of(context).cardColor,
                        padding: const EdgeInsets.all(6.0),
                        child: new Column(
                          children: <Widget>[
                            new Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                new Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    new Row(
                                      children: <Widget>[
                                        new Text("Period", style: Theme.of(context).textTheme.body1.apply(color: Theme.of(context).hintColor)),
                                        new Padding(padding: const EdgeInsets.only(right: 3.0)),
                                        new Text(historyTotal, style: Theme.of(context).textTheme.button),
                                        new Padding(padding: const EdgeInsets.only(right: 4.0)),
                                        new Text(num.parse(_change) > 0 ? "+" + _change+"%" : _change+"%",
                                            style: Theme.of(context).primaryTextTheme.body1.apply(
                                                fontWeightDelta: 1,
                                                color: num.parse(_change) >= 0 ? Colors.green : Colors.red
                                            )
                                        )
                                      ],
                                    ),
                                    new Padding(padding: const EdgeInsets.only(bottom: 1.5)),
                                    new Text("CCCAGG Data Set", style: Theme.of(context).textTheme.body1.apply(color: Theme.of(context).hintColor, fontSizeFactor: 0.7)),
                                  ],
                                ),
                                new Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    new Row(
                                      children: <Widget>[
                                        new Text("High", style: Theme.of(context).textTheme.body1.apply(color: Theme.of(context).hintColor)),
                                        new Padding(padding: const EdgeInsets.only(right: 3.0)),
                                        new Text("\$"+_high)
                                      ],
                                    ),
                                    new Row(
                                      children: <Widget>[
                                        new Text("Low", style: Theme.of(context).textTheme.body1.apply(color: Theme.of(context).hintColor)),
                                        new Padding(padding: const EdgeInsets.only(right: 3.0)),
                                        new Text("\$"+_low)
                                      ],
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ],
                        )
                    ),
                  ),
                  new Container(
                      child: new PopupMenuButton(
                        tooltip: "Select Period",
                        icon: new Icon(Icons.access_time, color: Theme.of(context).buttonColor),
                        itemBuilder: (BuildContext context) => [
                          new PopupMenuItem(child: new Text("1h"), value: ["minute", "60", "1h", "1"]),
                          new PopupMenuItem(child: new Text("6h"), value: ["minute", "360", "6h", "1"]),
                          new PopupMenuItem(child: new Text("12h"), value: ["minute", "720", "12h", "1"]),
                          new PopupMenuItem(child: new Text("24h"), value: ["minute", "720", "24h", "2"]),
                          new PopupMenuItem(child: new Text("3D"), value: ["hour", "72", "3D", "1"]),
                          new PopupMenuItem(child: new Text("7D"), value: ["hour", "168", "7D", "1"]),
                          new PopupMenuItem(child: new Text("1M"), value: ["hour", "720", "1M", "1"]),
                          new PopupMenuItem(child: new Text("3M"), value: ["day", "90", "3M", "1"]),
                          new PopupMenuItem(child: new Text("6M"), value: ["day", "180", "6M", "1"]),
                          new PopupMenuItem(child: new Text("1Y"), value: ["day", "365", "1Y", "1"]),
                        ],
                        onSelected: (result) {changeHistory(result[0], result[1], result[2], result[3]);},
                      )
                  ),
                ],
              ),
              new Flexible(
                child: new SingleChildScrollView(
                  controller: _scrollController,
                  child: new Column(
                    children: <Widget>[
                      sparkLineData != null && showSparkline ? new Container(
                        height: MediaQuery.of(context).size.height * 0.2,
                        padding: const EdgeInsets.all(8.0),
                        child: new Sparkline(
                          data: sparkLineData,
                          lineWidth: 1.8,
                          lineGradient: new LinearGradient(
                              colors: [Theme.of(context).accentColor, Theme.of(context).buttonColor],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter
                          ),
                        )
                      ) : new Container(height: MediaQuery.of(context).size.height * 0.2),
                      new Row(
                        children: <Widget>[
                          new Flexible(
                            child: new Container(
                              color: Theme.of(context).cardColor,
                              padding: const EdgeInsets.all(6.0),
                              child: new Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  new Row(
                                    children: <Widget>[
                                      new Text("Candlestick Width", style: Theme.of(context).textTheme.body1.apply(color: Theme.of(context).hintColor)),
                                      new Padding(padding: const EdgeInsets.only(right: 3.0)),
                                      new Text(OHLCVWidthOptions[historyTotal][currentOHLCVWidthSetting][0])
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          new Container(
                              child: new PopupMenuButton(
                                tooltip: "Select Width",
                                icon: new Icon(Icons.swap_horiz, color: Theme.of(context).buttonColor),
                                itemBuilder: (BuildContext context) {
                                  List<PopupMenuEntry<dynamic>> options = [];
                                  for (int i = 0; i < OHLCVWidthOptions[historyTotal].length; i++) {
                                    options.add(new PopupMenuItem(child: new Text(OHLCVWidthOptions[historyTotal][i][0]), value: i));
                                  }
                                  return options;
                                },
                                onSelected: (result) {
                                  changeOHLCVWidth(result);
                                },
                              )
                          ),
                        ],
                      ),

                      historyOHLCVTimeAggregated != null ? new Container(
                          height: MediaQuery.of(context).size.height * 0.6,
                          padding: const EdgeInsets.all(8.0),
                          child: new OHLCVGraph(
                            data: historyOHLCVTimeAggregated,
                            enableGridLines: true,
                            gridLineColor: Theme.of(context).dividerColor,
                            gridLineLabelColor: Theme.of(context).hintColor,
                            gridLineAmount: 5,
                            volumeProp: 0.2,
                          ),
                      ) : new Container(height: MediaQuery.of(context).size.height * 0.6),

                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      bottomNavigationBar: new BottomAppBar(
        elevation: bottomAppBarElevation,
        child: new QuickPercentChangeBar(snapshot: snapshot, bgColor: Theme.of(context).canvasColor),
      ),
    );
  }
}


class QuickPercentChangeBar extends StatelessWidget {
  QuickPercentChangeBar({this.snapshot, this.bgColor});
  final snapshot;
  final bgColor;

  @override
  Widget build(BuildContext context) {
    return new Container(
      padding: const EdgeInsets.only(left: 6.0, right: 6.0, bottom: 3.0, top: 3.0),
      color: bgColor != null ? bgColor : Theme.of(context).canvasColor,
      child: new Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          new Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              new Text("1H", style: Theme.of(context).textTheme.body1.apply(color: Theme.of(context).hintColor)),
              new Padding(padding: const EdgeInsets.only(right: 3.0)),
              new Text(
                  num.parse(snapshot["percent_change_1h"]) >= 0 ? "+"+snapshot["percent_change_1h"]+"%" : snapshot["percent_change_1h"]+"%",
                  style: Theme.of(context).primaryTextTheme.body1.apply(fontWeightDelta: 1,
                      color: num.parse(snapshot["percent_change_1h"]) >= 0 ? Colors.green : Colors.red
                  )
              ),
            ],
          ),
          new Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              new Text("24H", style: Theme.of(context).textTheme.body1.apply(color: Theme.of(context).hintColor)),
              new Padding(padding: const EdgeInsets.only(right: 3.0)),
              new Text(
                  num.parse(snapshot["percent_change_24h"]) >= 0 ? "+"+snapshot["percent_change_24h"]+"%" : snapshot["percent_change_24h"]+"%",
                  style: Theme.of(context).primaryTextTheme.body1.apply(fontWeightDelta: 1,
                      color: num.parse(snapshot["percent_change_24h"]) >= 0 ? Colors.green : Colors.red
                  )
              ),
            ],
          ),
          new Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              new Text("7D", style: Theme.of(context).textTheme.body1.apply(color: Theme.of(context).hintColor)),
              new Padding(padding: const EdgeInsets.only(right: 3.0)),
              new Text(
                  num.parse(snapshot["percent_change_7d"]) >= 0 ? "+"+snapshot["percent_change_7d"]+"%" : snapshot["percent_change_7d"]+"%",
                  style: Theme.of(context).primaryTextTheme.body1.apply(fontWeightDelta: 1,
                      color: num.parse(snapshot["percent_change_7d"]) >= 0 ? Colors.green : Colors.red
                  )
              ),
            ],
          )
        ],
      ),
    );
  }
}