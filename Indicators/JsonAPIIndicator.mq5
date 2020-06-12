//+------------------------------------------------------------------+
//|                                             JsonAPIIndicator.mq5 |
//|                                  Copyright 2020,  Gunther Schulz |
//|                                     https://www.guntherschulz.de |
//+------------------------------------------------------------------+

#property copyright "2020 Gunther Schulz"
#property link      "https://www.guntherschulz.de"
#property version   "1.00"

#include <EnumStringToInt.mqh>
#include <Zmq/Zmq.mqh>
#include <Json.mqh>

// Set ports and host for ZeroMQ
string HOST="localhost";
int CHART_SUB_PORT=15562;

// ZeroMQ Cnnections
Context context("MQL5 JSON API");
Socket chartSubscriptionSocket(context,ZMQ_SUB);

//--- input parameters
input string            IndicatorId="";
input string            ShortName="JsonAPI";
input string            LineLabel="Value";   
input string            ColorSyle = "clrRed";
input string            LineType = "DRAW_LINE";
input string            LineStyle = "STYLE_SOLID";
input int               LineWidth = 1;

//--- indicator settings
double                   Buffer[];
bool                     debug = false;
bool first = false;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
  bool result = chartSubscriptionSocket.connect(StringFormat("tcp://%s:%d", HOST, CHART_SUB_PORT));
  if (result == false) {Print("Failed to subscrbe on port ", CHART_SUB_PORT);} 
  else {
    Print("Accepting Chart Indicator data on port ", CHART_SUB_PORT);
    // TODO subscribe only to own IndicatorId topic
    // Subscribe to all topics
    chartSubscriptionSocket.setSubscribe("");
    chartSubscriptionSocket.setLinger(1000);
    // Number of messages to buffer in RAM.
    chartSubscriptionSocket.setReceiveHighWaterMark(5); // TODO confirm settings
  }
  
//--- indicator buffers mapping;
   ArraySetAsSeries(Buffer,true);
   SetIndexBuffer(0,Buffer,INDICATOR_DATA);
   SetIndexBuffer(1,Buffer,INDICATOR_CALCULATIONS);
   
   color colorstyle = StringToColor(ColorSyle);
   int linetype = StringToEnumInt(LineType);
   int linestyle = StringToEnumInt(LineStyle);
   SetStyle(ShortName, LineLabel, colorstyle, linetype, linestyle, LineWidth);
//---
   return(INIT_SUCCEEDED);
  }
  

void SetStyle(string shortname, string linelabel, color colorstyle, int linetype, int linestyle, int linewidth) {
  IndicatorSetString(INDICATOR_SHORTNAME,shortname);
  PlotIndexSetString(0,PLOT_LABEL,linelabel);
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
  // While a new candle is forming, set the current value to be empty
  if(rates_total>prev_calculated){
    Buffer[0] = EMPTY_VALUE;
  }
 
//--- return value of prev_calculated for next call
   return(rates_total);
  }

void SubscriptionHandler(ZmqMsg &chartMsg){
  CJAVal message;
  
  // Get data from reguest
  string msg=chartMsg.getData();
  if(debug) Print("Processing:"+msg);
  
  // Deserialize msg to CJAVal array
  if(!message.Deserialize(msg)){
    Alert("Deserialization Error");
    ExpertRemove();
  }
  if(message["indicatorChartId"]==IndicatorId) { 
    if(message["action"]=="PLOT") {
        WriteToBuffer(message);
    }
  }
}

//+------------------------------------------------------------------+
//| Update indicator buffer function                                 |
//+------------------------------------------------------------------+
void WriteToBuffer(CJAVal &message) {
  int bufferSize = ArraySize(Buffer);
  int messageDataSize = message["data"].Size();
  if(first==false) {
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
  // Set the most recent plotted value to nothing, as we do not have any data for yet unformed candles
  Buffer[0] = EMPTY_VALUE;
}


//+------------------------------------------------------------------+
//| Check for new indicator data function                            |
//+------------------------------------------------------------------+
void CheckMessages(){
  // This is a workaround for Timer(). It is needed, because OnTimer() works if the indicator is manually added to a chart, but not with ChartIndicatorAdd()

  ZmqMsg chartMsg;

  // Recieve chart instructions stream from client via live Chart socket.
  chartSubscriptionSocket.recv(chartMsg,true);

  // Request recieved
  if(chartMsg.size()>0){ 
    // Handle subscription SubscriptionHandler()
    SubscriptionHandler(chartMsg);
    ChartRedraw(ChartID());
  }
}

//+------------------------------------------------------------------+
//| OnTimer() workaround function                                    |
//+------------------------------------------------------------------+
// Gets triggered by the OnTimer() function of the JsonAPI Expert script
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
    if(id==CHARTEVENT_CUSTOM+222) CheckMessages();
  }
//+----------------------------------------------------
