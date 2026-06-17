//+------------------------------------------------------------------+
//| EMS Trinity Trading Robot                                        |
//| Engulfing + MSNR + Smart Money Context                           |
//| Based on "The EMS Trinity" by Yanu Emmanuel                      |
//| For Deriv Step Index - Multi-timeframe framework                 |
//+------------------------------------------------------------------+
#property copyright "EMS Trinity Trading Framework"
#property link "https://github.com/Love-0810/trading-bot"
#property version "1.00.00"
#property strict
#property description "Professional EMS Trinity EA with MSNR, Engulfing, and SMC logic"

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
// MSNR Class - Malaysian Support and Resistance
//+------------------------------------------------------------------+
class CMSNR
{
private:
    string symbol;
    ENUM_TIMEFRAMES higherTF;
    ENUM_TIMEFRAMES midTF;
    double resistance;
    double support;
    
public:
    void Init(string sym, ENUM_TIMEFRAMES htf, ENUM_TIMEFRAMES mtf)
    {
        symbol = sym;
        higherTF = htf;
        midTF = mtf;
        CalculateLevels();
    }
    
    void CalculateLevels()
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        int copied = CopyRates(symbol, higherTF, 0, 100, rates);
        if(copied < 50)
            return;
        
        double highest = rates[0].high;
        double lowest = rates[0].low;
        
        for(int i = 0; i < copied; i++)
        {
            if(rates[i].high > highest)
                highest = rates[i].high;
            if(rates[i].low < lowest)
                lowest = rates[i].low;
        }
        
        resistance = highest;
        support = lowest;
    }
    
    double GetResistanceLevel()
    {
        CalculateLevels();
        return resistance;
    }
    
    double GetSupportLevel()
    {
        CalculateLevels();
        return support;
    }
    
    bool CheckBreakoutSNR(double currentPrice)
    {
        return currentPrice > resistance || currentPrice < support;
    }
};

//+------------------------------------------------------------------+
// Engulfing Class - Engulfing Pattern Detection
//+------------------------------------------------------------------+
class CEngulfing
{
private:
    string symbol;
    ENUM_TIMEFRAMES timeframe;
    
public:
    void Init(string sym, ENUM_TIMEFRAMES tf)
    {
        symbol = sym;
        timeframe = tf;
    }
    
    int DetectEngulfing(string sym, ENUM_TIMEFRAMES tf)
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        int copied = CopyRates(sym, tf, 0, 3, rates);
        if(copied < 3)
            return 0;
        
        double prev_open = rates[1].open;
        double prev_close = rates[1].close;
        double prev_high = rates[1].high;
        double prev_low = rates[1].low;
        
        double curr_open = rates[0].open;
        double curr_close = rates[0].close;
        double curr_high = rates[0].high;
        double curr_low = rates[0].low;
        
        if(curr_open < prev_close && curr_close > prev_open && curr_close > prev_close)
        {
            return 1;
        }
        
        if(curr_open > prev_close && curr_close < prev_open && curr_close < prev_close)
        {
            return -1;
        }
        
        if(curr_close > curr_open && curr_close > prev_close && curr_open < prev_open)
        {
            return 1;
        }
        
        if(curr_close < curr_open && curr_close < prev_close && curr_open > prev_open)
        {
            return -1;
        }
        
        return 0;
    }
    
    bool CheckEngulfingFailure(string sym, ENUM_TIMEFRAMES tf, int engulfingSignal)
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        int copied = CopyRates(sym, tf, 0, 3, rates);
        if(copied < 3)
            return false;
        
        double engulf_close = rates[1].close;
        double curr_close = rates[0].close;
        
        if(engulfingSignal == 1)
        {
            return curr_close < engulf_close;
        }
        else if(engulfingSignal == -1)
        {
            return curr_close > engulf_close;
        }
        
        return false;
    }
};

//+------------------------------------------------------------------+
// SMC Class - Smart Money Context
//+------------------------------------------------------------------+
class CSMC
{
private:
    string symbol;
    ENUM_TIMEFRAMES midTF;
    ENUM_TIMEFRAMES execTF;
    
public:
    void Init(string sym, ENUM_TIMEFRAMES mtf, ENUM_TIMEFRAMES etf)
    {
        symbol = sym;
        midTF = mtf;
        execTF = etf;
    }
    
    bool CheckBreakOfStructure(string sym, ENUM_TIMEFRAMES tf, int direction)
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        int copied = CopyRates(sym, tf, 0, 10, rates);
        if(copied < 10)
            return false;
        
        if(direction == 1)
        {
            double prev_high = rates[2].high;
            for(int i = 3; i < 10; i++)
            {
                if(rates[i].high > prev_high)
                    prev_high = rates[i].high;
            }
            return rates[0].high > prev_high;
        }
        
        if(direction == -1)
        {
            double prev_low = rates[2].low;
            for(int i = 3; i < 10; i++)
            {
                if(rates[i].low < prev_low)
                    prev_low = rates[i].low;
            }
            return rates[0].low < prev_low;
        }
        
        return false;
    }
    
    bool CheckLiquiditySweep(string sym, ENUM_TIMEFRAMES tf, int direction)
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        int copied = CopyRates(sym, tf, 0, 20, rates);
        if(copied < 20)
            return false;
        
        double swing_high = rates[10].high;
        double swing_low = rates[10].low;
        
        for(int i = 5; i < 15; i++)
        {
            if(rates[i].high > swing_high)
                swing_high = rates[i].high;
            if(rates[i].low < swing_low)
                swing_low = rates[i].low;
        }
        
        if(direction == 1)
        {
            bool swept_low = rates[2].low < swing_low;
            bool reversing_up = rates[0].close > rates[1].close;
            return swept_low && reversing_up;
        }
        
        if(direction == -1)
        {
            bool swept_high = rates[2].high > swing_high;
            bool reversing_down = rates[0].close < rates[1].close;
            return swept_high && reversing_down;
        }
        
        return false;
    }
};

//+------------------------------------------------------------------+
// Risk Management Class
//+------------------------------------------------------------------+
class CRiskManagement
{
private:
    double accountBalance;
    double riskPercent;
    double minLotSize;
    double maxLotSize;
    double lotStep;
    
public:
    void Init(double balance, double risk)
    {
        accountBalance = balance;
        riskPercent = risk;
        
        minLotSize = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
        maxLotSize = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
        lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    }
    
    double CalculateVolume(double entryPrice, double stopLossPrice)
    {
        if(entryPrice == 0 || stopLossPrice == 0)
            return 0;
        
        double riskAmount = accountBalance * (riskPercent / 100.0);
        double pipsRisk = MathAbs(entryPrice - stopLossPrice) / SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        
        if(pipsRisk == 0)
            return 0;
        
        double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
        
        if(tickValue == 0)
            return 0;
        
        double volume = riskAmount / (pipsRisk * tickValue);
        
        if(volume < minLotSize)
            volume = minLotSize;
        if(volume > maxLotSize)
            volume = maxLotSize;
        
        volume = MathFloor(volume / lotStep) * lotStep;
        
        return volume;
    }
    
    double CalculateRR(double entry, double tp, double sl)
    {
        double risk = MathAbs(entry - sl);
        double reward = MathAbs(tp - entry);
        
        if(risk == 0)
            return 0;
        
        return reward / risk;
    }
    
    double GetBalance()
    {
        return AccountInfoDouble(ACCOUNT_BALANCE);
    }
};

//+------------------------------------------------------------------+
// Input Parameters
//+------------------------------------------------------------------+
input group "=== RISK MANAGEMENT ==="
input double RiskPercent = 1.0;
input double MinRiskReward = 3.0;
input int MaxOpenTrades = 1;

input group "=== FILTER SETTINGS ==="
input bool UseMSNRFilter = true;
input bool UseEngulfingFilter = true;
input bool UseStructureFilter = true;
input bool UseLiquiditySweepFilter = true;

input group "=== TIMEFRAME SETTINGS ==="
input ENUM_TIMEFRAMES HigherTimeframe = PERIOD_D1;
input ENUM_TIMEFRAMES MidTimeframe = PERIOD_H4;
input ENUM_TIMEFRAMES ExecutionTimeframe = PERIOD_H1;

input group "=== TRADE MANAGEMENT ==="
input bool EnablePartialTP = true;
input double PartialTPPercent = 50.0;
input bool TrailStopOnProfit = true;
input int TrailStopPoints = 50;

input group "=== LOGGING & ALERTS ==="
input bool EnableLogging = true;
input bool SendAlerts = true;
input bool SendEmailAlerts = false;

//+------------------------------------------------------------------+
// Global Variables
//+------------------------------------------------------------------+
CTrade trade;
CMSNR msnr;
CEngulfing engulfing;
CSMC smc;
CRiskManagement risk;

ulong lastTradeTicket = 0;
double lastEntryPrice = 0;
datetime lastTradeTime = 0;

//+------------------------------------------------------------------+
// OnInit Function
//+------------------------------------------------------------------+
int OnInit()
{
    if(HigherTimeframe <= ExecutionTimeframe)
    {
        Alert("Error: Higher timeframe must be larger than execution timeframe!");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    if(MinRiskReward < 1.5)
    {
        Alert("Warning: MinRiskReward should be >= 1.5 for profitability");
    }
    
    trade.SetExpertMagicNumber(20260617);
    trade.SetDeviationInPoints(10);
    
    msnr.Init(Symbol(), HigherTimeframe, MidTimeframe);
    engulfing.Init(Symbol(), HigherTimeframe);
    smc.Init(Symbol(), MidTimeframe, ExecutionTimeframe);
    risk.Init(AccountInfoDouble(ACCOUNT_BALANCE), RiskPercent);
    
    if(EnableLogging)
        Print("=== EMS Trinity EA Initialized ===");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
// OnTick Function
//+------------------------------------------------------------------+
void OnTick()
{
    if(CountOpenTrades() >= MaxOpenTrades)
        return;
    
    int bias = GetDirectionalBias();
    
    if(bias == 0)
        return;
    
    int engulfingSignal = DetectEngulfingSignal(bias);
    
    if(engulfingSignal == 0)
        return;
    
    bool structureConfirmed = ConfirmMarketStructure(engulfingSignal);
    
    if(!structureConfirmed && UseStructureFilter)
        return;
    
    bool liquiditySweepFound = CheckLiquiditySweep(engulfingSignal);
    
    if(!liquiditySweepFound && UseLiquiditySweepFilter)
        return;
    
    double entryPrice, stopLoss, takeProfit;
    
    if(!CalculateEntryLevels(engulfingSignal, entryPrice, stopLoss, takeProfit))
        return;
    
    double rr = CalculateRR(entryPrice, takeProfit, stopLoss);
    
    if(rr < MinRiskReward)
    {
        if(EnableLogging)
            Print("RR ", rr, " below minimum ", MinRiskReward);
        return;
    }
    
    ExecuteTrade(engulfingSignal, entryPrice, stopLoss, takeProfit, rr);
}

//+------------------------------------------------------------------+
// Get Directional Bias
//+------------------------------------------------------------------+
int GetDirectionalBias()
{
    if(!UseMSNRFilter)
        return 1;
    
    double resistance = msnr.GetResistanceLevel();
    double support = msnr.GetSupportLevel();
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    
    if(currentPrice > resistance)
        return 1;
    else if(currentPrice < support)
        return -1;
    else
        return 0;
}

//+------------------------------------------------------------------+
// Detect Engulfing Signal
//+------------------------------------------------------------------+
int DetectEngulfingSignal(int bias)
{
    if(!UseEngulfingFilter)
        return bias;
    
    int signal = engulfing.DetectEngulfing(Symbol(), HigherTimeframe);
    
    if(signal == bias)
        return signal;
    
    return 0;
}

//+------------------------------------------------------------------+
// Confirm Market Structure
//+------------------------------------------------------------------+
bool ConfirmMarketStructure(int signal)
{
    if(!UseStructureFilter)
        return true;
    
    bool bos = smc.CheckBreakOfStructure(Symbol(), MidTimeframe, signal);
    bool liquiditySweep = smc.CheckLiquiditySweep(Symbol(), MidTimeframe, signal);
    
    return (bos || liquiditySweep);
}

//+------------------------------------------------------------------+
// Check Liquidity Sweep
//+------------------------------------------------------------------+
bool CheckLiquiditySweep(int signal)
{
    if(!UseLiquiditySweepFilter)
        return true;
    
    return smc.CheckLiquiditySweep(Symbol(), MidTimeframe, signal);
}

//+------------------------------------------------------------------+
// Calculate Entry Levels
//+------------------------------------------------------------------+
bool CalculateEntryLevels(int signal, double &entryPrice, double &stopLoss, double &takeProfit)
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    int copied = CopyRates(Symbol(), ExecutionTimeframe, 0, 5, rates);
    if(copied < 5)
        return false;
    
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    
    if(signal == 1)
    {
        entryPrice = ask;
        stopLoss = rates[0].low - (2 * SymbolInfoDouble(Symbol(), SYMBOL_POINT));
        
        double risk = entryPrice - stopLoss;
        takeProfit = entryPrice + (risk * MinRiskReward);
    }
    else
    {
        entryPrice = bid;
        stopLoss = rates[0].high + (2 * SymbolInfoDouble(Symbol(), SYMBOL_POINT));
        
        double risk = stopLoss - entryPrice;
        takeProfit = entryPrice - (risk * MinRiskReward);
    }
    
    return true;
}

//+------------------------------------------------------------------+
// Calculate Risk-to-Reward Ratio
//+------------------------------------------------------------------+
double CalculateRR(double entry, double tp, double sl)
{
    double risk = MathAbs(entry - sl);
    double reward = MathAbs(tp - entry);
    
    if(risk == 0)
        return 0;
    
    return reward / risk;
}

//+------------------------------------------------------------------+
// Execute Trade
//+------------------------------------------------------------------+
void ExecuteTrade(int signal, double entry, double sl, double tp, double rr)
{
    double volume = risk.CalculateVolume(entry, sl);
    
    if(volume <= 0)
    {
        if(EnableLogging)
            Print("Invalid volume calculated");
        return;
    }
    
    string comment = StringFormat("EMS_RR%.1f_%s", rr, (signal == 1 ? "BUY" : "SELL"));
    
    if(signal == 1)
    {
        if(trade.Buy(volume, Symbol(), entry, sl, tp, comment))
        {
            lastTradeTicket = trade.ResultOrder();
            lastEntryPrice = entry;
            lastTradeTime = TimeCurrent();
            
            if(EnableLogging)
                Print("BUY Order executed - Ticket: ", lastTradeTicket, " RR: ", rr);
            
            if(SendAlerts)
                Alert("EMS BUY Signal - RR: ", rr, " Entry: ", entry);
        }
    }
    else
    {
        if(trade.Sell(volume, Symbol(), entry, sl, tp, comment))
        {
            lastTradeTicket = trade.ResultOrder();
            lastEntryPrice = entry;
            lastTradeTime = TimeCurrent();
            
            if(EnableLogging)
                Print("SELL Order executed - Ticket: ", lastTradeTicket, " RR: ", rr);
            
            if(SendAlerts)
                Alert("EMS SELL Signal - RR: ", rr, " Entry: ", entry);
        }
    }
}

//+------------------------------------------------------------------+
// Count Open Trades
//+------------------------------------------------------------------+
int CountOpenTrades()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == Symbol())
                count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
// OnDeinit Function
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(EnableLogging)
        Print("=== EMS Trinity EA Deinitialized - Reason: ", reason, " ===");
}
