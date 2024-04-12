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
input double FOLLOWING = 1;
input double PSAR = 0.01;
input int BB_PERIOD = 20;
input int BB_DEVI = 2;
input int MONEY = 10000;

double lotBuy,lotSell;
double followingPoint,oldLineTP,stoploss;
bool stFollow,stChangeStoploss;
datetime D1;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
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

   double high[],low[],close[];
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
   CopyHigh(Symbol(),PERIOD_CURRENT,0,10,high);
   CopyLow(Symbol(),PERIOD_CURRENT,0,10,low);
   CopyClose(Symbol(),PERIOD_CURRENT,0,10,close);

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

      if(close[2] < sarArray[2] && close[1] > sarArray[1] && high[1] < upperBandArray[1])
        {
         bool result = checkStateConditionBuy();
         if(result == true)
            signal = "Buy";
        }

      //--- SELL  CONDITION   ---//
      if(close[1] > sarArray[1])
         sellOnce = true;

      if(close[2] > sarArray[2] && close[1] < sarArray[1] && low[1] > lowerBandArray[1])
        {
         bool result = checkStateConditionSell();
         if(result == true)
            signal = "Sell";
        }

      //--- FOLLOWING   ZONE  ---//
      if(PositionsTotal() < 1)
        {
         followingPoint = 0;
         stFollow = false;
         oldLineTP = false;
         stChangeStoploss = false;
        }
      else
        {
         if(D1  != iTime(Symbol(),PERIOD_CURRENT,0))
           {
            followingTakeprofit();
            D1 = iTime(Symbol(),PERIOD_CURRENT,0);
           }   // end   if(D1 != iTime())
        }

      //--- BUY   ORDER ---//
      if(signal == "Buy" && buyOnce == true && PositionsTotal() < 1)
        {
         double Ask = NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_ASK),Digits());
         trade.Buy(lotBuy,Symbol(),Ask,sarArray[1],NULL,NULL);
         buyOnce = false;
        }

      //---SELL ORDER ---//
      if(signal == "Sell" && sellOnce == true && PositionsTotal() < 1)
        {
         double Bid = NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_BID),Digits());
         trade.Sell(lotSell,Symbol(),Bid,sarArray[1],NULL,NULL);
         sellOnce = false;
        }
     }     // end if(err == false)
  }      // end   void Ontick()
//+------------------------------------------------------------------+

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
void followingTakeprofit()
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(Symbol() == PositionGetSymbol(i))
        {
         ulong positionTicket = PositionGetInteger(POSITION_TICKET);
         double currentOpen = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentTP = PositionGetDouble(POSITION_TP);

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           {
            if(stChangeStoploss == false)
              {
               stoploss = PositionGetDouble(POSITION_SL);
               stChangeStoploss = true;
              }

            double diff = currentOpen - stoploss;
            double lineTP = ((followingPoint + FOLLOWING) * diff) + currentOpen;
            double followTP = (followingPoint * diff) + currentOpen;
            double tralingLine = ((followingPoint - FOLLOWING) * diff) + currentOpen;
            double Ask = NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_ASK),Digits());

            if(Ask >= lineTP && stFollow == false)
              {
               trade.PositionModify(positionTicket,followTP,currentTP);

               oldLineTP = lineTP;
               followingPoint = followingPoint + FOLLOWING;
               stFollow = true;
              }

            if(followTP >= oldLineTP)
               stFollow = false;
           }      // END   POSITION BUY

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
           {
            if(stChangeStoploss == false)
              {
               stoploss = PositionGetDouble(POSITION_SL);
               stChangeStoploss = true;
              }

            double diff = stoploss - currentOpen;
            double lineTP = currentOpen - ((followingPoint + FOLLOWING) * diff);
            double followTP = currentOpen - (followingPoint * diff);
            double tralingLine = currentOpen - ((followingPoint - FOLLOWING) * diff);
            double Bid = NormalizeDouble(SymbolInfoDouble(Symbol(),SYMBOL_BID),Digits());

            if(Bid <= lineTP && stFollow == false)
              {
               trade.PositionModify(positionTicket,followTP,currentTP);

               oldLineTP = lineTP;
               followingPoint = followingPoint + FOLLOWING;
               stFollow = true;
              }

            if(followTP <= oldLineTP)
               stFollow = false;
           }      // END   POSITION SELL
        }
     }
  }
//+------------------------------------------------------------------+
