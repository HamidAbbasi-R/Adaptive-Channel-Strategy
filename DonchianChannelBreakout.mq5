//+------------------------------------------------------------------+
//| Donchian Channel Breakout Bot                                     |
//+------------------------------------------------------------------+
#include <trade/trade.mqh>
enum sessionsChoices
   {
   AllSessions,
   AsiaSession,
   LondonSession,
   NewYorkSession,
   AsiaANDLondon,
   LondonANDNewYork,
   NewYorkANDAsia,
   };
input sessionsChoices session = AllSessions;    // Active sessions
input int Length = 20;                          // Donchian Channel lookback period

input group "Risk Management"
input double SLtoBreathRatio = 1.0;                       // SL to channel breath ratio
input double riskPercentage = 1.0;              // Risk percentage
input double rewardToRisk = 2.0;                // Reward to Risk ratio

input group "Filters"
enum marketRegimes
   {
   breakout,
   ranging,
   breakout_ranging,
   };
input marketRegimes marketregime = breakout_ranging;        // Market regime
enum filterChoices
   {
   ADX,
   Volume,
   both,
   };
input filterChoices filterChoice = ADX;         // Filtering option
input double VolumeBreakoutMultiplier = 1.1;    // Multiplier for volume filter (breakout)
input double VolumeRangingMultiplier = 1.0;     // Multiplier for volume filter (ranging)
input int ADX_period = 14;                      // ADX period
enum ADXfilterOptions
   {
   One,
   Two,
   Three,
   };
input ADXfilterOptions ADXoption = One;         // Number of ADX thresholds
input double ADX_first= 40;                     // Upper ADX threhsold (trending), The first option
input double ADX_lower = 20;                    // Lower ADX threhsold (ranging)
input double ADX_extreme = 15;                  // Extreme low ADX (ranging)


//--- trade object
CTrade trade;

//--- global variables
double UpperBound[], LowerBound[], MidBound[], adx[], slPts, VolumeSMA;
int handle_DNC, handle_ADX;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- initialization
   handle_DNC = iCustom(NULL, PERIOD_CURRENT, "Free Indicators/Donchian Channel", Length, false);  // Upper line
   handle_ADX = iADX(NULL,PERIOD_CURRENT, ADX_period);
   return(INIT_SUCCEEDED);
  }



//+------------------------------------------------------------------+
//| Main bot logic executed on every new tick                        |
//+------------------------------------------------------------------+
void OnTick(){
   CopyBuffer(handle_DNC, 0, 0, 1, UpperBound);
   CopyBuffer(handle_DNC, 1, 0, 1, MidBound);
   CopyBuffer(handle_DNC, 2, 0, 1, LowerBound);
   CopyBuffer(handle_ADX, 0, 0, 1, adx);
   
   // Get the current volume
   long currentVolume = iVolume(NULL, PERIOD_CURRENT, 0);
   // Calculate SMA of volume for the last 14 bars
   long sumVolume = 0;
   for (int i = 0; i < Length; i++){
      sumVolume += iVolume(NULL, PERIOD_CURRENT, i);
   }
   VolumeSMA = double(sumVolume) / Length;
   //Print("current vol=", currentVolume, ",     vol SMA=", VolumeSMA);
   
   double bid = SymbolInfoDouble(NULL, SYMBOL_BID);
   double ask = SymbolInfoDouble(NULL, SYMBOL_ASK);

   //--- Check for open trades
   if (PositionsTotal() == 0 && IsTimeCond()){ // No open positions
      
      if (bid > UpperBound[0]){ // Price breaks above the upper bound
         
         bool breakoutCondADX = adx[0] > ADX_first;
         bool breakoutCondVol = currentVolume > VolumeSMA*VolumeBreakoutMultiplier;
         bool breakoutCond;
         if (filterChoice==ADX){
            breakoutCond = breakoutCondADX;   
         }else if(filterChoice==Volume){
            breakoutCond = breakoutCondVol;
         }else{
            breakoutCond = breakoutCondADX && breakoutCondVol;
         }
         
         bool rangingCondADX = (ADXoption==One && adx[0]<ADX_first) || (ADXoption==Two && adx[0]<ADX_lower) || (ADXoption==Three && adx[0]<ADX_lower);
         bool rangingCondVol =  currentVolume < VolumeSMA*VolumeRangingMultiplier;
         bool rangingCond;
         if (filterChoice==ADX){
            rangingCond = rangingCondADX;   
         }else if(filterChoice==Volume){
            rangingCond = rangingCondVol;
         }else{
            rangingCond = rangingCondADX && rangingCondVol;
         }
         
         if(breakoutCond && (marketregime==breakout_ranging || marketregime==breakout)){    // trending
            double sl = ask - (ask - MidBound[0]) * SLtoBreathRatio;
            executeBuy(sl);
         }else if(rangingCond && (marketregime==breakout_ranging || marketregime==ranging)){      // ranging
            double sl = bid + (bid - MidBound[0]) * SLtoBreathRatio;
            executeSell(sl);
         }
         
      }else if (ask < LowerBound[0]){     // Price breaks below the lower bound
      
      
         bool breakoutCondADX = adx[0] > ADX_first;
         bool breakoutCondVol = currentVolume > VolumeSMA*VolumeBreakoutMultiplier;
         bool breakoutCond;
         if (filterChoice==ADX){
            breakoutCond = breakoutCondADX;   
         }else if(filterChoice==Volume){
            breakoutCond = breakoutCondVol;
         }else{
            breakoutCond = breakoutCondADX && breakoutCondVol;
         }
         
         bool rangingCondADX = (ADXoption==One && adx[0]<ADX_first) || (ADXoption==Two && adx[0]<ADX_lower) || (ADXoption==Three && adx[0]<ADX_lower);
         bool rangingCondVol =  currentVolume < VolumeSMA*VolumeRangingMultiplier;
         bool rangingCond;
         if (filterChoice==ADX){
            rangingCond = rangingCondADX;   
         }else if(filterChoice==Volume){
            rangingCond = rangingCondVol;
         }else{
            rangingCond = rangingCondADX && rangingCondVol;
         }
         
         
         if(breakoutCond && (marketregime==breakout_ranging || marketregime==breakout)){    // trending
            double sl = bid + (MidBound[0] - bid) * SLtoBreathRatio;
            executeSell(sl);
         }else if(rangingCond && (marketregime==breakout_ranging || marketregime==ranging)){      // ranging
            double sl = ask - (MidBound[0] - ask) * SLtoBreathRatio;
            executeBuy(sl);
         }
         
      }else if(filterChoice==ADX && ADXoption==Three && adx[0] < ADX_extreme){
         // Price goes through a fraction of either of boundares when ADX is extremely low
         double fracUpBound   = UpperBound[0] - 0.1 * (UpperBound[0] - MidBound[0]);
         double fracDownBound = LowerBound[0] + 0.1 * (MidBound[0]   - LowerBound[0]);
         
         if(bid > fracUpBound){
            double sl = bid + (bid - MidBound[0]) * SLtoBreathRatio;
            executeSell(sl);
         }else if(ask < fracDownBound){
            double sl = ask - (MidBound[0] - ask) * SLtoBreathRatio;
            executeBuy(sl);
         }
      }
   }
}


void executeBuy(double sl){
   double entry = SymbolInfoDouble(NULL, SYMBOL_ASK);
   int dgts = (int)SymbolInfoInteger(NULL, SYMBOL_DIGITS);
   
   entry = NormalizeDouble(entry, dgts);
   sl = NormalizeDouble(sl, dgts);

   double tp = entry + (entry-sl)*rewardToRisk;
   tp = NormalizeDouble(tp, dgts);
   
   slPts = (entry - sl) / _Point;
   Print("sl=",sl, "    tp=",tp, "     entry=",entry);
   double lots = CalculateLotSize();
   trade.Buy(lots, NULL, entry, sl, tp);
}

void executeSell(double sl){
   double entry = SymbolInfoDouble(NULL, SYMBOL_BID);
   int dgts = (int)SymbolInfoInteger(NULL, SYMBOL_DIGITS);
      
   entry = NormalizeDouble(entry, dgts);
   sl = NormalizeDouble(sl, dgts);
   
   double tp = entry - (sl-entry)*rewardToRisk;
   tp = NormalizeDouble(tp, dgts);
   
   slPts = (sl - entry) / _Point;
   
   double lots = CalculateLotSize();
   trade.Sell(lots, NULL, entry, sl, tp);
}

double CalculateLotSize(){
   // Get the current account balance
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk = accountBalance * riskPercentage / 100.0;    
   double tickSize = SymbolInfoDouble(NULL,SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(NULL, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(NULL, SYMBOL_VOLUME_STEP);
   
   //double moneyPerLotStep = sl_points / tickSize * tickValue * lotStep;
   double moneyPerLotStep = slPts*tickValue;
   double lots = risk / moneyPerLotStep;
   int digits = int(-MathLog10(lotStep));
   lots = NormalizeDouble(lots,digits);
   
   return lots;
}



bool IsInSession(int startHour, int endHour){
   // Get the current server time in UTC (TimeCurrent returns server time in seconds)
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   
   // Extract the hour part of the current time (in UTC)
   int currentHour = timeStruct.hour;
   int currentMinute = timeStruct.min;
   
   // Check if we are in the first 10 minutes of the day when startHour is 0
   if (startHour == 0 && currentHour == 0 && currentMinute < 20)
      return false;  // Exclude the first 10 minutes of the day
   
   // Check if the current hour is within the London session range
   if (currentHour >= startHour && currentHour < endHour)
      return true;  // It's during the London session
   else
      return false; // It's outside the London session
}

bool IsTimeCond(){
   if(session == AllSessions){return true;};

   if(session == AsiaSession    && IsInSession(0,10)){return true;};
   if(session == LondonSession  && IsInSession(10,19)){return true;};
   if(session == NewYorkSession && IsInSession(15,24)){return true;};
   
   if(session == LondonANDNewYork && IsInSession(10,24)){return true;};
   if(session == AsiaANDLondon    && IsInSession(0,19)){return true;};
   if(session == NewYorkANDAsia   && !IsInSession(10,15)){return true;};
 
   return false;
}