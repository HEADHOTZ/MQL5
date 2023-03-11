#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
CTrade trade;
input double Risk = 1;
input double TP = 1;
input double Parabolic_Sar = 0.02;
input int MA = 200;
input int ATR = 14;
input bool TralingStop = false;
input int MONEY = 1000;
input ENUM_MA_METHOD MA_Method = MODE_SMA;
datetime D1;

void OnTick()
{
   double Lots_Buy,Lots_Sell,Risk_Amount;
   //---------SIGNAL-------------
   string signal = "";
   string signal_order = "";
   static bool buy_once = false;
   static bool sell_once = false; 
   //---------SIGNAL-------------
   //-----------------PRICE---------------------
   double high[],low[],close[];
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
   CopyHigh(Symbol(),PERIOD_CURRENT,0,10,high);
   CopyLow(Symbol(),PERIOD_CURRENT,0,10,low);
   CopyClose(Symbol(),PERIOD_CURRENT,0,10,close);
   //-----------------PRICE---------------------
   //------------------------------MOVING AVERAGE----------------------------
   double MovingAverageArray[];
   int movingAverage = iMA(Symbol(),PERIOD_CURRENT,MA,0,MA_Method,PRICE_CLOSE);
   ArraySetAsSeries(MovingAverageArray,true);
   CopyBuffer(movingAverage,0,0,3,MovingAverageArray);
   //------------------------------MOVING AVERAGE----------------------------
   //------------------------PARABOLIC SAR----------------------
   double SarArray[];
   double sar = iSAR(Symbol(),PERIOD_CURRENT,Parabolic_Sar,0.2);
   ArraySetAsSeries(SarArray,true);
   CopyBuffer(sar,0,0,3,SarArray);
   double SL = SarArray[1];
   //------------------------PARABOLIC SAR----------------------
   //---------------------ATR------------------------
   double atrArray[];
   int atr_value = iATR(Symbol(),PERIOD_CURRENT,ATR);
   ArraySetAsSeries(atrArray,true);
   CopyBuffer(atr_value,0,0,3,atrArray);
   //---------------------ATR------------------------
   //-----------------------------CHECK DATA------------------------------------------------
   //check buy
   if(close[1] < SarArray[1])
   { 
      signal = "pre_buy";
      buy_once = true;
   }
   //check sell
   else if(close[1] > SarArray[1])
   {
      signal = "pre_sell";
      sell_once = true;
   }
   //buy order
   if(signal == "pre_sell" && close[1] > SarArray[1] && close[1] > MovingAverageArray[1])
   {
      signal_order = "buy";
   }
   //sell order
   else if(signal == "pre_buy" && close[1] < SarArray[1] && close[1] < MovingAverageArray[1])
   {
      signal_order = "sell";
   }
   //-----------------------------CHECK DATA------------------------------------------------
   //--------------------------------SETUP-------------------------------
   double sl_buy = (low[1] - atrArray[1]);
   double sl_sell = (high[1] + atrArray[1]);
   double diff_buy = (close[1] - sl_buy) / _Point;
   double diff_sell = (sl_sell - close[1]) / _Point;
   double tp_buy = (close[1] - sl_buy) * TP;
   double tp_sell = (sl_sell - close[1]) * TP;
   double min_lot = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   if(Symbol() == "XAUUSD")
   {
      Risk_Amount = MONEY * (Risk / 100);
      Lots_Buy = NormalizeDouble((close[1] - sl_buy) * 100,2);
      Lots_Sell = NormalizeDouble((sl_sell - close[1]) * 100,2);
   }
   else if(Symbol() == "XAGUSD")
   {
      Risk_Amount = MONEY * (Risk / 100);
      Lots_Buy = NormalizeDouble((close[1] - sl_buy) * 5000,2);
      Lots_Sell = NormalizeDouble((sl_sell - close[1]) * 5000,2);
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
   //-------------------------------OPEN ORDER------------------------------------
   if(signal_order == "buy" && buy_once == true)
   {
      double Ask = NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_ASK),Digits());
      trade.Buy(Lots_Buy,Symbol(),Ask,sl_buy,Ask+tp_buy,NULL);
      buy_once = false;
   }
   if(signal_order == "sell" && sell_once == true)
   {
      double Bid = NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_BID),Digits());
      trade.Sell(Lots_Sell,Symbol(),Bid,sl_sell,Bid-tp_sell,NULL);
      sell_once = false;
   }
   //-------------------------------OPEN ORDER------------------------------------
   //------------------------TRALING STOP---------------------------
   if(D1 != iTime(Symbol(),PERIOD_CURRENT,0) && TralingStop == true)
   {
      if(SarArray[1] < close[1])
      {
         CheckTralingStopBuy(SL);
      }
      if(SarArray[1] > close[1])
      {
         CheckTralingStopSell(SL);
      }
      D1 = iTime(Symbol(),PERIOD_CURRENT,0);
   }
   //------------------------TRALING STOP---------------------------
   
   Comment("MovingAverage: ",MovingAverageArray[1],"\n"
            "Sar : ",SarArray[1],"\n"
            "ATR : ",atrArray[1],"\n"
            "High : ",high[1],"\n"
            "Low : ",low[1],"\n"
            "Close : ",close[1],"\n"
            "Signal : ",signal,"\n"
            "Signal Order : ",signal_order,"\n"
            "Lots_Buy : ",Lots_Buy,"\n"
            "Lots_Sell : ",Lots_Sell,"\n"
            "MinLot : ",min_lot,"\n"
            "maxLot : ",max_lot);
}

void CheckTralingStopBuy(double SL)
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      string symbol = PositionGetSymbol(i);
      if(Symbol() == symbol)
      {
         ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
         double CurrentStoploss = PositionGetDouble(POSITION_SL);
         if (CurrentStoploss < SL)
         {
            trade.PositionModify(PositionTicket,SL,0);
         }
      }
   }
}

void CheckTralingStopSell(double SL)
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      string symbol = PositionGetSymbol(i);
      if(Symbol() == symbol)
      {
         ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
         double CurrentStoploss = PositionGetDouble(POSITION_SL);
         if (CurrentStoploss > SL)
         {
            trade.PositionModify(PositionTicket,SL,0);
         }
      }
   }
}