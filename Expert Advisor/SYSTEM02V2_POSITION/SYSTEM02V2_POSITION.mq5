//+------------------------------------------------------------------+
//|                                                         SYSTEM02 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

CTrade trade;

enum ORDER_POSITION
  {
   L=0,     // Long
   S=1,     // Short
   A=2,     // ALL
  };

input double RISK = 1;
input double TP = 1;
input double PSAR = 0.01;
input int BB_PERIOD = 20;
input  ORDER_POSITION POSITION = L;
input bool TRALINGSTOP = false;
input bool SAFE_TP = false;
input int BB_DEVI = 2;
input int MONEY = 10000;
input double MIN_PROFIT_FACTOR = 1.25;
input double TP_TESTER = 0.75;

double lotBuy,lotSell;
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

      double upperBandArray[],lowerBandArray[];
      int band = iBands(Symbol(),PERIOD_CURRENT,BB_PERIOD,0,BB_DEVI,PRICE_CLOSE);
      ArraySetAsSeries(upperBandArray,true);
      ArraySetAsSeries(lowerBandArray,true);
      CopyBuffer(band,1,0,3,upperBandArray);
      CopyBuffer(band,2,0,3,lowerBandArray);

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
      double spreadSL =  spread * Point();

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
      double tpBuy = (close[1] - sarArray[1]) * TP;
      double tpSell = ((sarArray[1] - close[1]) * TP);

      double risk = MONEY * (RISK / 100);

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
         if(close[2] < sarArray[2] && close[1] > sarArray[1])
           {
            bool result = checkStateConditionBuy();
            if(result == true)
               signal = "Buy";
           }

         //--- SELL  CONDITION   ---//
         if(close[2] > sarArray[2] && close[1] < sarArray[1])
           {
            bool result = checkStateConditionSell();
            if(result == true)
               signal = "Sell";
           }

         //--- BUY   ORDER ---//
         if(signal == "Buy" && NoOpenOrdersForSymbol() == true)
           {
            if(POSITION == L || POSITION == A)
              {
               double Ask = NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_ASK),Digits());
               trade.Buy(lotBuy,Symbol(),Ask,sarArray[1] - spreadSL,open[0]+tpBuy,NULL);  // Not test but if having problem,you should check this line and visual test for sure
               // And should check about open order the algorithm should open at open current price
              }
           }

         //---SELL ORDER ---//
         if(signal == "Sell"  && NoOpenOrdersForSymbol() == true)
           {
            if(POSITION == S || POSITION == A)
              {
               double Bid = NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_BID),Digits());
               trade.Sell(lotSell,Symbol(),Bid,sarArray[1] + spreadSL,open[0]-tpSell,NULL);
              }
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
bool NoOpenOrdersForSymbol()
  {
   for(int i = 0; i < PositionsTotal(); i++)
     {
      if(PositionSelect(Symbol()))
        {
         return false; // Found an open position for the current symbol
        }
     }
   return true; // No open positions for the current symbol
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool checkStateConditionBuy()
  {
   bool stateBuy = false;
   int i = 3;
   double low[], close[], sarArray[],upperBand[],lowerBand[];

   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(sarArray, true);
   ArraySetAsSeries(upperBand, true);
   ArraySetAsSeries(lowerBand,true);

   while(i < Bars(Symbol(),PERIOD_CURRENT) - 1)
     {
      CopyLow(Symbol(), PERIOD_CURRENT, 0, i + 10, low);
      CopyClose(Symbol(), PERIOD_CURRENT, 0, i + 10, close);

      int psar = iSAR(Symbol(), PERIOD_CURRENT, PSAR, 0.2);
      CopyBuffer(psar, 0, 0, i + 3, sarArray);

      int band = iBands(Symbol(),PERIOD_CURRENT,BB_PERIOD,0,BB_DEVI,PRICE_CLOSE);
      CopyBuffer(band,1,0,i+3,upperBand);
      CopyBuffer(band,2,0,i+3,lowerBand);

      if(close[i] < sarArray[i])
        {
         if(low[i] < lowerBand[i])
           {
            Print(low[i]);
            stateBuy = true;
           }
        }
      else
        {
         break;
        }
      i++;
     }
   Print(stateBuy);
   return stateBuy;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool checkStateConditionSell()
  {
   bool stateSell = false;
   int i = 3;
   double high[], close[], sarArray[],upperBand[],lowerBand[];

   ArraySetAsSeries(high,true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(sarArray, true);
   ArraySetAsSeries(upperBand, true);
   ArraySetAsSeries(lowerBand,true);

   while(i < Bars(Symbol(),PERIOD_CURRENT) - 1)
     {
      CopyHigh(Symbol(), PERIOD_CURRENT, 0, i + 10, high);
      CopyClose(Symbol(), PERIOD_CURRENT, 0, i + 10, close);

      int psar = iSAR(Symbol(), PERIOD_CURRENT, PSAR, 0.2);
      CopyBuffer(psar, 0, 0, i + 3, sarArray);

      int band = iBands(Symbol(),PERIOD_CURRENT,BB_PERIOD,0,BB_DEVI,PRICE_CLOSE);
      CopyBuffer(band,1,0,i+3,upperBand);
      CopyBuffer(band,2,0,i+3,lowerBand);

      if(close[i] > sarArray[i])
        {
         if(high[i] > upperBand[i])
           {
            Print(high[i]);
            stateSell = true;
           }
        }
      else
        {
         break;
        }
      i++;
     }
   Print(stateSell);
   return stateSell;
  }

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
