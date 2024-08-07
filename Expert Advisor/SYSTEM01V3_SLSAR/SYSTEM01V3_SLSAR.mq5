//+------------------------------------------------------------------+
//|                                                         SYSTEM02 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

CTrade trade;

input double RISK = 1;
input double TP = 1;
input double PSAR = 0.01;
input int EMA = 200;
input bool TRALINGSTOP = false;
input bool SAFE_TP = false;
input int MONEY = 10000;
input double MIN_PROFIT_FACTOR = 1.25;
input double TP_TESTER = 0.75;

double lotBuy,lotSell,tpBuy,tpSell;
datetime D1;

//+------------------------------------------------------------------+
//|   Tester function                                                |
//+------------------------------------------------------------------+
double OnTester()
  {
   double profitFactor = TesterStatistics(STAT_PROFIT_FACTOR);

   if(TP > TP_TESTER && TRALINGSTOP == false)
     {
      return 0.0;
     }

   if(profitFactor < MIN_PROFIT_FACTOR)
     {
      return 0.0;   // Skip the result when factor is less than MIN_PROFIT_FACTOR
     }

   return profitFactor;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(D1  != iTime(Symbol(),PERIOD_CURRENT,0))
     {
      //--- SETUP ZONE  ---//
      double sarArray[];
      int psar = iSAR(Symbol(),PERIOD_CURRENT,PSAR,0.2);
      ArraySetAsSeries(sarArray,true);
      CopyBuffer(psar,0,0,3,sarArray);

      double maArray[];
      int ma = iMA(Symbol(),PERIOD_CURRENT,EMA,0,MODE_EMA,PRICE_CLOSE);
      ArraySetAsSeries(maArray,true);
      CopyBuffer(ma,0,0,3,maArray);

      double high[],low[],close[],open[];
      ArraySetAsSeries(high,true);
      ArraySetAsSeries(low,true);
      ArraySetAsSeries(close,true);
      ArraySetAsSeries(open,true);
      CopyHigh(Symbol(),PERIOD_CURRENT,0,10,high);
      CopyLow(Symbol(),PERIOD_CURRENT,0,10,low);
      CopyClose(Symbol(),PERIOD_CURRENT,0,10,close);
      CopyOpen(Symbol(),PERIOD_CURRENT,0,10,open);


      long spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
      double spreadPoint =  spread * Point();

      static bool buyOnce = false;
      static bool sellOnce = false;

      string signal = "";

      //--- ZONE  FIX   ERROR ---//
      static bool err = false;
      if((close[1] - sarArray[1]) == 0)
         err = true;
      else
         err = false;

      //--- ZONE  RISK  REWARD   ---//
      double diffBuy = (close[1] - sarArray[1]) / _Point;
      double diffSell = ((sarArray[1] - close[1]) / _Point);
      double risk = MONEY * (RISK / 100);

      tpBuy = open[0] + ((close[1] - sarArray[1]) * TP);
      tpSell = open[0] - ((sarArray[1] - close[1]) * TP);

      if(err == false)
        {
         if(Symbol() == "XAUUSDm")
           {
            lotBuy = NormalizeDouble(risk / ((close[1] - sarArray[1]) * 100),2);
            lotSell = NormalizeDouble(risk / ((sarArray[1] - close[1]) * 100),2);
           }

         else
            if(Symbol() == "XAGUSDm")
              {
               lotBuy = NormalizeDouble(risk / ((close[1] - sarArray[1]) * 5000),2);
               lotSell = NormalizeDouble(risk / ((sarArray[1] - close[1]) * 5000),2);
              }

            else
              {
               lotBuy = NormalizeDouble(risk / diffBuy,2);
               lotSell = NormalizeDouble(risk / diffSell,2);
              }

         if(lotBuy < SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN))
            lotBuy = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
         if(lotSell < SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN))
            lotSell = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);

         if(lotBuy > SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX))
            lotBuy = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
         if(lotSell > SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX))
            lotSell = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);

         //--- BUY   CONDITION   ---//
         if(close[1] < sarArray[1])
           {
            buyOnce = true;
           }

         if(close[1] > sarArray[1] && close[1] > maArray[1])
           {
            signal = "Buy";
           }

         //--- SELL  CONDITION   ---//
         if(close[1] > sarArray[1])
           {
            sellOnce = true;
           }

         if(close[1] < sarArray[1] && close[1] < maArray[1])
           {
            signal = "Sell";
           }

         //--- BUY   ORDER ---//
         if (signal == "Buy" && buyOnce == true)
           {
            double Ask = NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_ASK),Digits());
            trade.Buy(lotBuy,Symbol(),Ask,sarArray[1] - spreadPoint,tpBuy - spreadPoint,NULL);  // Not test but if having problem,you should check this line and visual test for sure
            // And should check about open order the algorithm should open at open current price
            buyOnce = false;
           }

         //---SELL ORDER ---//
         if(signal == "Sell"  && sellOnce == true)
           {
            double Bid = NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_BID),Digits());
            trade.Sell(lotSell,Symbol(),Bid,sarArray[1] + spreadPoint,tpSell + spreadPoint,NULL);
            sellOnce = false;
           }
  
         if(TRALINGSTOP == true && SAFE_TP == false)
            tralingStop(sarArray[1]);

         if(SAFE_TP == true && TRALINGSTOP == false)
            safeTP();
         D1 = iTime(Symbol(),PERIOD_CURRENT,0);
        }     // end if(err == false)
     }
  }      // end   void Ontick()
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void  tralingStop(double stoploss)
  {
   long spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
   double spreadSL =  spread * Point();

   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(Symbol() == PositionGetSymbol(i))
        {
         ulong positionTicket = PositionGetInteger(POSITION_TICKET);
         double currentStoploss  = PositionGetDouble(POSITION_SL);
         double currentTP = PositionGetDouble(POSITION_TP);

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && currentStoploss < stoploss)
           {
            trade.PositionModify(positionTicket,stoploss - spreadSL,currentTP);
           }

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && currentStoploss > stoploss)
           {
            trade.PositionModify(positionTicket,stoploss + spreadSL,currentTP);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void safeTP()
  {
   for(int i=PositionsTotal() - 1; i>=0; i--)
     {
      if(Symbol() == PositionGetSymbol(i))
        {
         ulong positionTicket = PositionGetInteger(POSITION_TICKET);
         double currentStoploss  = PositionGetDouble(POSITION_SL);
         double currentOpen = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentTP = PositionGetDouble(POSITION_TP);

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && currentStoploss < currentOpen)
           {
            double safeTakeprofit = (currentOpen - currentStoploss) + currentOpen;
            Print("Safe TP BUY : ",safeTakeprofit);
            double Ask = NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_ASK),Digits());
            if(Ask >= safeTakeprofit)
               trade.PositionModify(positionTicket,currentOpen,currentTP);
           }

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && currentStoploss > currentOpen)
           {
            double safeTakeprofit = currentOpen - (currentStoploss - currentOpen);
            Print("Safe TP SELL : ",safeTakeprofit);
            double Bid = NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_BID),Digits());
            if(Bid <= safeTakeprofit)
               trade.PositionModify(positionTicket,currentOpen,currentTP);
           }
        }
     }
  }
//+------------------------------------------------------------------+


