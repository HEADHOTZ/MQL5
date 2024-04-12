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
  };

input double RISK = 1;
input double TP = 1;
input double PSAR = 0.01;
input int BB_PERIOD = 20;
input  ORDER_POSITION POSITION = L;
input bool SAFE_TP = false;
input bool TRALINGSTOP = false;
input int BB_DEVI = 2;
input int MONEY = 10000;

double lotBuy,lotSell;

datetime D1;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- SETUP ZONE  ---//
   double sarArray[];
   double psar = iSAR(Symbol(),PERIOD_CURRENT,PSAR,0.2);
   ArraySetAsSeries(sarArray,true);
   CopyBuffer(psar,0,0,3,sarArray);

   double upperBandArray[],lowerBandArray[];
   double band = iBands(Symbol(),PERIOD_CURRENT,BB_PERIOD,0,BB_DEVI,PRICE_CLOSE);
   ArraySetAsSeries(upperBandArray,true);
   ArraySetAsSeries(lowerBandArray,true);
   CopyBuffer(band,1,0,3,upperBandArray);
   CopyBuffer(band,2,0,3,lowerBandArray);

   double high[],low[],close[];
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
   CopyHigh(Symbol(),PERIOD_CURRENT,0,10,high);
   CopyLow(Symbol(),PERIOD_CURRENT,0,10,low);
   CopyClose(Symbol(),PERIOD_CURRENT,0,10,close);

   static bool buyOnce = false;
   static bool sellOnce = false;

   static bool stateBuy = false;
   static bool stateSell = false;

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
      if(Symbol() == "XAUUSD")
        {
         lotBuy = NormalizeDouble(risk / ((close[1] - sarArray[1]) * 100),2);
         lotSell = NormalizeDouble(risk / ((sarArray[1] - close[1]) * 100),2);
        }

      else
         if(Symbol() == "XAGUSD")
           {
            lotBuy = NormalizeDouble(risk / ((close[1] - sarArray[1]) * 5000),2);
            lotSell = NormalizeDouble(risk / ((sarArray[1] - close[1]) * 5000),2);
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

      //--- BUY   CONDITION   ---//
      if(close[1] < sarArray[1])
         buyOnce = true;

      if(low[1] < lowerBandArray[1] && close[1] < sarArray[1])
        {
         stateBuy = true;
         stateSell = false;
        }

      if(close[2] < sarArray[2] && close[1] > sarArray[1])
         signal = "Buy";

      //--- SELL  CONDITION   ---//
      if(close[1] > sarArray[1])
         sellOnce = true;

      if(high[1] > upperBandArray[1] && close[1] > sarArray[1])
        {
         stateBuy = false;
         stateSell = true;
        }

      if(close[2] > sarArray[2] && close[1] < sarArray[1])
         signal = "Sell";

      //--- BUY   ORDER ---//
      if(signal == "Buy" && stateBuy == true && buyOnce == true && PositionsTotal() < 1 && POSITION == L)
        {
         double Ask = NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_ASK),Digits());
         trade.Buy(lotBuy,Symbol(),Ask,sarArray[1],Ask+tpBuy,NULL);
         buyOnce = false;
         stateBuy = false;
        }

      //---SELL ORDER ---//
      if(signal == "Sell" && stateSell == true && sellOnce == true && PositionsTotal() < 1 && POSITION == S)
        {
         double Bid = NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_BID),Digits());
         trade.Sell(lotSell,Symbol(),Bid,sarArray[1],Bid-tpSell,NULL);
         sellOnce = false;
         stateSell = false;
        }

      if(D1  != iTime(Symbol(),PERIOD_CURRENT,0))
        {
         if(TRALINGSTOP == true && SAFE_TP == false)
            tralingStop(sarArray[1]);
         if(SAFE_TP == true && TRALINGSTOP == false)
            safeTP();
         D1 = iTime(Symbol(),PERIOD_CURRENT,0);
        }   // end   if(D1 != iTime())
     }     // end if(err == false)
  }      // end   void Ontick()
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void  tralingStop(double stoploss)
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(Symbol() == PositionGetSymbol(i))
        {
         ulong positionTicket = PositionGetInteger(POSITION_TICKET);
         double currentStoploss  = PositionGetDouble(POSITION_SL);
         double currentTP = PositionGetDouble(POSITION_TP);

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && currentStoploss < stoploss)
           {
            trade.PositionModify(positionTicket,stoploss,currentTP);
           }

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && currentStoploss > stoploss)
           {
            trade.PositionModify(positionTicket,stoploss,currentTP);
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
