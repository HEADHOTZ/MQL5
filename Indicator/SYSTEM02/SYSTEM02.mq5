//+------------------------------------------------------------------+
//|                                                     SYSTEM02.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3
//--- plot SL
#property indicator_label1  "SL"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSalmon
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- plot TP
#property indicator_label2  "TP"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGold
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
//--- plot EN
#property indicator_label3  "EN"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrWhite
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1
//--- input parameters
input int DAY = 1;
input double RISK = 1;
input double TP = 1;
input int MONEY = 10000;
input double PSAR = 0.01;
input int BB_PERIOD = 20;
input int BB_DEVI = 2;
//--- indicator buffers
double         SLBuffer[];
double         TPBuffer[];
double         ENBuffer[];
//--- call  variable
double lotBuy,lotSell;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,SLBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,TPBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ENBuffer,INDICATOR_DATA);
//---
   return(INIT_SUCCEEDED);
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
//---
   int uncalculatedBar = rates_total - prev_calculated;
   for(int i = 0;i < uncalculatedBar;i++)
     {
      //--- SETUP  ZONE   ---//
      double sarArray[];
      int sar = iSAR(Symbol(),PERIOD_CURRENT,PSAR,0.2);
      ArraySetAsSeries(sarArray,true);
      CopyBuffer(sar,0,0,DAY+3,sarArray);

      double high[],low[],close[];
      ArraySetAsSeries(high,true);
      ArraySetAsSeries(low,true);
      ArraySetAsSeries(close,true);
      CopyHigh(Symbol(),PERIOD_CURRENT,0,DAY+10,high);
      CopyLow(Symbol(),PERIOD_CURRENT,0,DAY+10,low);
      CopyClose(Symbol(),PERIOD_CURRENT,0,DAY+10,close);

      double spreadPoint = spread[0] *_Point;

      double diffBuy = (close[DAY] - sarArray[DAY]) / _Point;
      double diffSell = (sarArray[DAY] - close[DAY]) / _Point;
      double tpBuy = (close[DAY] - sarArray[DAY]) * TP;
      double tpSell = (sarArray[DAY] - close[DAY]) * TP;

      double risk = MONEY * (RISK / 100);

      if(Symbol() == "XAUUSD")
        {
         lotBuy = NormalizeDouble(risk / ((close[DAY] - sarArray[DAY]) * 100),2);
         lotSell = NormalizeDouble(risk / ((sarArray[DAY] - close[DAY]) * 100),2);
        }
      else
         if(Symbol() == "XAGUSD")
           {
            lotBuy = NormalizeDouble(risk / ((close[DAY] - sarArray[DAY]) * 5000),2);
            lotSell = NormalizeDouble(risk / ((sarArray[DAY] - close[DAY]) * 5000),2);
           }
         else
           {
            lotBuy = NormalizeDouble(risk / diffBuy,2);
            lotSell = NormalizeDouble(risk / diffSell,2);
           }

      if(lotBuy < 0.01)
         lotBuy = 0.01;
      if(lotSell < 0.01)
         lotSell = 0.01;
         
      //---BUY CONDITION   ---//
      if(close[DAY+1] < sarArray[DAY+1] && close[DAY] > sarArray[DAY])
        {
         ENBuffer[i] = close[DAY];
         SLBuffer[i] = sarArray[DAY] - spreadPoint;
         TPBuffer[i] = ((ENBuffer[i] - sarArray[DAY]) * TP) + ENBuffer[i];

         ObjectDelete(1,"LOTSELL");
         ObjectCreate(0,"LOTBUY",OBJ_LABEL,0,0,0);
         ObjectSetString(0,"LOTBUY",OBJPROP_FONT,"Arial");
         ObjectSetInteger(0,"LOTBUY",OBJPROP_COLOR,clrGreenYellow);
         ObjectSetInteger(0,"LOTBUY",OBJPROP_FONTSIZE,24);
         ObjectSetInteger(0,"LOTBUY",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
         ObjectSetInteger(0,"LOTBUY",OBJPROP_XDISTANCE,225);
         ObjectSetInteger(0,"LOTBUY",OBJPROP_YDISTANCE,25);
         ObjectSetString(0,"LOTBUY",OBJPROP_TEXT,0,"Lot Size : " + DoubleToString(lotBuy,2));
        }
      else
         ObjectDelete(0,"LOTBUY");
      if(close[DAY+1] > sarArray[DAY+1] && close[DAY] < sarArray[DAY])
        {
         ENBuffer[i] = close[DAY];
         SLBuffer[i] = sarArray[DAY] + spreadPoint;
         TPBuffer[i] = ENBuffer[i] - ((sarArray[DAY] - ENBuffer[i])*TP);
         ObjectDelete(0,"LOTBUY");
         ObjectCreate(1,"LOTSELL",OBJ_LABEL,0,0,0);
         ObjectSetString(1,"LOTSELL",OBJPROP_FONT,"Arial");
         ObjectSetInteger(1,"LOTSELL",OBJPROP_COLOR,clrLightSalmon);
         ObjectSetInteger(1,"LOTSELL",OBJPROP_FONTSIZE,24);
         ObjectSetInteger(1,"LOTSELL",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
         ObjectSetInteger(1,"LOTSELL",OBJPROP_XDISTANCE,225);
         ObjectSetInteger(1,"LOTSELL",OBJPROP_YDISTANCE,25);
         ObjectSetString(1,"LOTSELL",OBJPROP_TEXT,0,"Lot Size : " + DoubleToString(lotSell,2));
        }
      else
         ObjectDelete(1,"LOTSELL");
     }   // end for loop
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
