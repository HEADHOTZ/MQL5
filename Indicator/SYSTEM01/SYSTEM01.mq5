//+------------------------------------------------------------------+
//|                                                     SYSTEM01.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window

#property indicator_buffers 3
#property indicator_plots 3

#property indicator_label1  "SL"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSalmon
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "EN"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrWhite
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_label3  "TP"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGold
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- indicator buffers
input int day = 1;
input double Risk = 1;
input double TP = 1;
input double Parabolic_Sar = 0.01;
input int MA = 200;
input int ATR = 14;
input int MONEY = 10000;
input ENUM_MA_METHOD MA_Method = MODE_SMA;

double         SLBuffer[];
double         ENBuffer[];
double         TPBuffer[];

double Lots_Buy,Lots_Sell;
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
   
   for(int i = 0;i < uncalculatedBar; i++)
   {
      double Lots_Buy,Lots_Sell,Risk_Amount;
      //-----------------PRICE---------------------
      double high[],low[],close[];
      ArraySetAsSeries(high,true);
      ArraySetAsSeries(low,true);
      ArraySetAsSeries(close,true);
      CopyHigh(Symbol(),PERIOD_CURRENT,0,day+10,high);
      CopyLow(Symbol(),PERIOD_CURRENT,0,day+10,low);
      CopyClose(Symbol(),PERIOD_CURRENT,0,day+10,close);
      double close_periode = close[day];
      double high_periode = high[day];
      double low_periode = low[day];
      //-----------------PRICE---------------------
      //------------------------------MOVING AVERAGE----------------------------
      double MovingAverageArray[];
      int movingAverage = iMA(Symbol(),PERIOD_CURRENT,MA,0,MA_Method,PRICE_CLOSE);
      ArraySetAsSeries(MovingAverageArray,true);
      CopyBuffer(movingAverage,0,0,day+3,MovingAverageArray);
      double Moving_value = MovingAverageArray[day];
      //------------------------------MOVING AVERAGE----------------------------
      //------------------------PARABOLIC SAR----------------------
      double SarArray[];
      double sar = iSAR(Symbol(),PERIOD_CURRENT,Parabolic_Sar,0.2);
      ArraySetAsSeries(SarArray,true);
      CopyBuffer(sar,0,0,day+3,SarArray);
      double Sar_value = SarArray[day];
      //------------------------PARABOLIC SAR----------------------
      //---------------------ATR------------------------
      double atrArray[];
      int atr_val = iATR(Symbol(),PERIOD_CURRENT,ATR);
      ArraySetAsSeries(atrArray,true);
      CopyBuffer(atr_val,0,0,day+3,atrArray);
      double atr_value = atrArray[day];
      //---------------------ATR------------------------
      //--------------------------------SETUP-------------------------------
      double sl_buy = (low_periode - atr_value);
      double sl_sell = (high_periode - atr_value);
      double diff_buy = (close_periode - sl_buy) / _Point;
      double diff_sell = (sl_sell - close_periode) / _Point;
      double tp_buy = (close_periode - sl_buy) * TP;
      double tp_sell = (sl_sell - close_periode) * TP;
      double min_lot = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
      if(Symbol() == "XAUUSD")
      {
         Risk_Amount = MONEY * (Risk / 100);
         Lots_Buy = NormalizeDouble((close_periode - sl_buy) * 100,2);
         Lots_Sell = NormalizeDouble((sl_sell - close_periode) * 100,2);
      }
      else if(Symbol() == "XAGUSD")
      {
         Risk_Amount = MONEY * (Risk / 100);
         Lots_Buy = NormalizeDouble((close_periode - sl_buy) * 5000,2);
         Lots_Sell = NormalizeDouble((sl_sell - close_periode) * 5000,2);
      }
      else
      {
         Risk_Amount = MONEY * (Risk / 100);
         Lots_Buy = NormalizeDouble(Risk_Amount/diff_buy,2);
         Lots_Sell = NormalizeDouble(Risk_Amount/diff_sell,2);
      }
      if(Lots_Buy < min_lot)
      { 
         Lots_Buy = min_lot;
      }
      if(Lots_Buy > max_lot)
      {
         Lots_Buy = max_lot;
      }
      if(Lots_Sell < min_lot)
      { 
         Lots_Sell = min_lot;
      }
      if(Lots_Sell > max_lot)
      {
         Lots_Sell = max_lot;
      }
      //--------------------------------SETUP-------------------------------
      if(close_periode > Sar_value && close_periode > Moving_value)
      {
         ENBuffer[i] = close_periode;
         SLBuffer[i] = low_periode - atr_value;
         TPBuffer[i] = ((ENBuffer[i] - SLBuffer[i]) * TP) + ENBuffer[i];
         ObjectDelete(1,"LOTSELL");
         ObjectCreate(0,"LOTBUY",OBJ_LABEL,0,0,0);   
         ObjectSetString(0,"LOTBUY",OBJPROP_FONT,"Arial");
         ObjectSetInteger(0,"LOTBUY",OBJPROP_COLOR,clrGreenYellow); 
         ObjectSetInteger(0,"LOTBUY",OBJPROP_FONTSIZE,24);
         ObjectSetInteger(0,"LOTBUY",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
         ObjectSetInteger(0,"LOTBUY",OBJPROP_XDISTANCE,225);
         ObjectSetInteger(0,"LOTBUY",OBJPROP_YDISTANCE,25);
         ObjectSetString(0,"LOTBUY",OBJPROP_TEXT,0,"Lot Size : " + DoubleToString(Lots_Buy,2));
      }
      else if(close_periode < Sar_value && close_periode < Moving_value)
      {
         ENBuffer[i] = close_periode;
         SLBuffer[i] = low_periode - atr_value;
         TPBuffer[i] = ENBuffer[i] - ((SLBuffer[i] - ENBuffer[i]) *TP);  
         ObjectDelete(0,"LOTBUY"); 
         ObjectCreate(1,"LOTSELL",OBJ_LABEL,0,0,0);   
         ObjectSetString(1,"LOTSELL",OBJPROP_FONT,"Arial");
         ObjectSetInteger(1,"LOTSELL",OBJPROP_COLOR,clrLightSalmon); 
         ObjectSetInteger(1,"LOTSELL",OBJPROP_FONTSIZE,24);
         ObjectSetInteger(1,"LOTSELL",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
         ObjectSetInteger(1,"LOTSELL",OBJPROP_XDISTANCE,225);
         ObjectSetInteger(1,"LOTSELL",OBJPROP_YDISTANCE,25);
         ObjectSetString(1,"LOTSELL",OBJPROP_TEXT,0,"Lot Size : " + DoubleToString(Lots_Sell,2));
      }
      else
      {
         ObjectDelete(0,"LOTBUY"); 
         ObjectDelete(1,"LOTSELL");
      }
   }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
