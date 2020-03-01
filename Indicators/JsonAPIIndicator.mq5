//+------------------------------------------------------------------+
//|                                             JsonAPIIndicator.mq5 |
//|                                  Copyright 2020,  Gunther Schulz |
//|                                     https://www.guntherschulz.de |
//+------------------------------------------------------------------+

#property copyright "2020 Gunther Schulz"
#property link      "https://www.guntherschulz.de"
#property version   "1.00"

#include <StringToEnumInt.mqh>
#include <Zmq/Zmq.mqh>
#include <Json.mqh>

// Set ports and host for ZeroMQ
string HOST="localhost";
int CHART_SUB_PORT=15562;

// ZeroMQ Cnnections
Context context("MQL5 JSON API");
Socket chartLiveSocket(context,ZMQ_SUB);

//#property indicator_separate_window
//#property indicator_buffers 1
//#property indicator_plots   1
//---- plot MA
//#property indicator_label1  "MA"
//#property indicator_type1   DRAW_LINE
//#property indicator_color1  clrRed
//#property indicator_style1  STYLE_SOLID
//#property indicator_width1  1

//--- input parameters
input string            IndicatorId="";
input string            ShortName="JsonAPI";   
input string            ColorSyle = "clrRed";
input string            LineType = "DRAW_LINE";
input string            LineStyle = "STYLE_SOLID";
input int               LineWidth = 1;

//--- indicator settings
double                   Buffer[];
bool                     debug = false;

bool first = false;

//double Values[];
//ENUM_TIMEFRAMES originalTF = ChartPeriod();

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
  bool result = chartLiveSocket.connect(StringFormat("tcp://%s:%d", HOST, CHART_SUB_PORT));
  if (result == false) {Print("Failed to subscrbe on port ", CHART_SUB_PORT);} 
  else {
    Print("Accepting Chart Indicator data on port ", CHART_SUB_PORT);
    chartLiveSocket.setSubscribe("");
    chartLiveSocket.setLinger(1000);
    // Number of messages to buffer in RAM.
    chartLiveSocket.setReceiveHighWaterMark(5); // TODO confirm settings
  }
  
//--- indicator buffers mapping;
   ArraySetAsSeries(Buffer,true);
   SetIndexBuffer(0,Buffer,INDICATOR_DATA);
   
   color colorstyle = StringToColor(ColorSyle);
   int linetype = StringToEnumInt(LineType);
   int linestyle = StringToEnumInt(LineStyle);
   SetStyle(ShortName, colorstyle, linetype, linestyle, LineWidth);
//---
   return(INIT_SUCCEEDED);
  }
  

void SetStyle(string shortname, color colorstyle, int linetype, int linestyle, int linewidth) {
  IndicatorSetString(INDICATOR_SHORTNAME,shortname);
  PlotIndexSetInteger(0,PLOT_LINE_COLOR,0,colorstyle);
  PlotIndexSetInteger(0,PLOT_DRAW_TYPE,linetype);
  PlotIndexSetInteger(0,PLOT_LINE_STYLE,linestyle);
  PlotIndexSetInteger(0,PLOT_LINE_WIDTH,linewidth);
}
  
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
  // While a new candle is forming, set the current value to the previous value
  if(rates_total>prev_calculated){
    Buffer[0] = EMPTY_VALUE;
  }
  
/*
https://www.mql5.com/en/docs/constants/structures/mqlparam

*/
  
 
//--- return value of prev_calculated for next call
   return(rates_total);
  }

void SubscriptionHandler(ZmqMsg &chartMsg){
  CJAVal message;
        
  //ResetLastError();
  
  // Get data from reguest
  string msg=chartMsg.getData();
  if(debug) Print("Processing:"+msg);
  
  // Deserialize msg to CJAVal array
  if(!message.Deserialize(msg)){
    //ActionDoneOrError(65537, __FUNCTION__);
    Alert("Deserialization Error");
    ExpertRemove();
  }
  if(message["indicatorChartId"]==IndicatorId) WriteToBuffer(message);
}

void WriteToBuffer(CJAVal &message) {
  int bufferSize = ArraySize(Buffer);
  int messageDataSize = message["data"].Size();
  if(first==false) {
    //ArrayFill(Buffer, 0, ArraySize(Buffer), EMPTY_VALUE);
    PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,bufferSize-messageDataSize);
    first = true;
  }

  for(int i=0;i<messageDataSize;i++){
    // don't add more elements than the automatically sized buffer array can hold
    if(i+1<bufferSize){
      // the first element is the current unformed candle, so we start at index 1               
      // we reverse the order of the incoming values, which are expected to be ascending
      Buffer[i+1] = message["data"][messageDataSize-1-i].ToDbl();
    }
  }
  Buffer[0] = EMPTY_VALUE;
  
  
  
  //ArrayResize(Values, bufferSize);
 //for(int i=0;i<bufferSize;i++){
 //   Values[i] = Buffer[i];
 // }
 //   Print(Buffer[1], " ", Values[1]);
}

/*

TODO:

display drawing when the last history price arrived, not on first live signal

buy/sell arrows
create custom symbols for backtest data
restore after time frame change. try valuestore again?
  alternative: set Buffer to all EMPTY_VALUE, if not the original TF
dependable redraw after calling timer

*/

void CheckMessages(){
  // Timer() works, when the indicator is manually added to a chart, but not with ChartIndicatorAdd()

  ZmqMsg chartMsg;

  // Recieve chart instructions stream from client via live Chart socket.
  chartLiveSocket.recv(chartMsg,true);

  // Request recived
  if(chartMsg.size()>0){ 
    // Handle subscription SubscriptionHandler().
    Print(chartMsg.getData());
    SubscriptionHandler(chartMsg);
    ChartRedraw(ChartID());
  }
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
    //if(id==CHARTEVENT_CUSTOM+222 && sparam==IndicatorId) CheckMessages();
    if(id==CHARTEVENT_CUSTOM+222) CheckMessages();
  }
//+----------------------------------------------------
