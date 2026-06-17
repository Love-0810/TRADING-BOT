//+------------------------------------------------------------------+
//| EMS Trinity Trading Robot                                        |
//| Engulfing + MSNR + Smart Money Context                           |
//| Based on "The EMS Trinity" by Yanu Emmanuel                      |
//| For Deriv Step Index - Multi-timeframe framework                 |
//+------------------------------------------------------------------+
#property copyright "EMS Trinity Trading Framework"
#property link "https://github.com/Love-0810/trading-bot"
#property version "1.0.0"
#property strict
#property description "Professional EMS Trinity EA with MSNR, Engulfing, and SMC logic"

#include <Trade/Trade.mqh>
#include "include/MSNR.mqh"
#include "include/Engulfing.mqh"
#include "include/SMC.mqh"
#include "include/RiskManagement.mqh"

//+------------------------------------------------------------------+
// Input Parameters
//+------------------------------------------------------------------+
input group "=== RISK MANAGEMENT ==="
input double RiskPercent = 1.0;                    // Risk % per trade
input double MinRiskReward = 3.0;                  // Minimum RR ratio
input int MaxOpenTrades = 1;                       // Maximum simultaneous trades

input group "=== FILTER SETTINGS ==="
input bool UseMSNRFilter = true;                   // Use MSNR directional filter
input bool UseEngulfingFilter = true;              // Require engulfing confirmation
input bool UseStructureFilter = true;              // Require SMC structure confirmation
input bool UseLiquiditySweepFilter = true;         // Require liquidity sweep

input group "=== TIMEFRAME SETTINGS ==="
input ENUM_TIMEFRAMES HigherTimeframe = PERIOD_D1;    // D1 for engulfing
input ENUM_TIMEFRAMES MidTimeframe = PERIOD_H4;       // H4 for structure
input ENUM_TIMEFRAMES ExecutionTimeframe = PERIOD_H1; // H1 for entries

input group "=== TRADE MANAGEMENT ==="
input bool EnablePartialTP = true;                 // Take partial profits
input double PartialTPPercent = 50.0;              // % of position for partial TP
input bool TrailStopOnProfit = true;               // Trailing stop after TP1
input int TrailStopPoints = 50;                    // Points for trailing stop

input group "=== LOGGING & ALERTS ==="
input bool EnableLogging = true;                   // Log all signals
input bool SendAlerts = true;                      // Send platform alerts
input bool SendEmailAlerts = false;                // Send email alerts

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
    // Validate timeframes
    if(HigherTimeframe <= ExecutionTimeframe)
    {
        Alert("Error: Higher timeframe must be larger than execution timeframe!");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    if(MinRiskReward < 1.5)
    {
        Alert("Warning: MinRiskReward should be >= 1.5 for profitability");
    }
    
    // Initialize trade object
    trade.SetExpertMagicNumber(20260617);
    trade.SetDeviationInPoints(10);
    
    // Initialize modules
    msnr.Init(Symbol(), HigherTimeframe, MidTimeframe);
    engulfing.Init(Symbol(), HigherTimeframe);
    smc.Init(Symbol(), MidTimeframe, ExecutionTimeframe);
    risk.Init(AccountInfoDouble(ACCOUNT_BALANCE), RiskPercent);
    
    if(EnableLogging)
        Print("=== EMS Trinity EA Initialized ===");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
// OnTick Function - Main Trading Logic
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if we have a pending order or open position
    if(CountOpenTrades() >= MaxOpenTrades)
        return;
    
    // Step 1: Establish Directional Bias using MSNR
    int bias = GetDirectionalBias();
    
    if(bias == 0)
    {
        if(EnableLogging && TimeCurrent() % 1000 == 0)
            Print("No clear directional bias detected");
        return;
    }
    
    // Step 2: Detect Engulfing on Higher Timeframe
    int engulfingSignal = DetectEngulfingSignal(bias);
    
    if(engulfingSignal == 0)
        return;
    
    // Step 3: Confirm with Market Structure on Mid Timeframe
    bool structureConfirmed = ConfirmMarketStructure(engulfingSignal);
    
    if(!structureConfirmed && UseStructureFilter)
        return;
    
    // Step 4: Check for Liquidity Sweep
    bool liquiditySweepFound = CheckLiquiditySweep(engulfingSignal);
    
    if(!liquiditySweepFound && UseLiquiditySweepFilter)
        return;
    
    // Step 5: Calculate Entry, SL, TP with Risk Management
    double entryPrice, stopLoss, takeProfit;
    
    if(!CalculateEntryLevels(engulfingSignal, entryPrice, stopLoss, takeProfit))
        return;
    
    // Step 6: Validate Risk-to-Reward Ratio
    double rr = CalculateRR(entryPrice, takeProfit, stopLoss);
    
    if(rr < MinRiskReward)
    {
        if(EnableLogging)
            Print("RR ", rr, " below minimum ", MinRiskReward);
        return;
    }
    
    // Step 7: Execute Trade
    ExecuteTrade(engulfingSignal, entryPrice, stopLoss, takeProfit, rr);
}

//+------------------------------------------------------------------+
// Step 1: Get Directional Bias using MSNR
//+------------------------------------------------------------------+
int GetDirectionalBias()
{
    if(!UseMSNRFilter)
        return 1; // Default bullish
    
    // Get higher timeframe MSNR levels
    double resistance = msnr.GetResistanceLevel();
    double support = msnr.GetSupportLevel();
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    
    // Check if price is above/below key levels
    if(currentPrice > resistance)
        return 1; // Bullish bias
    else if(currentPrice < support)
        return -1; // Bearish bias
    else
        return 0; // No clear bias
}

//+------------------------------------------------------------------+
// Step 2: Detect Engulfing Signal
//+------------------------------------------------------------------+
int DetectEngulfingSignal(int bias)
{
    if(!UseEngulfingFilter)
        return bias;
    
    // Check for engulfing on higher timeframe
    int signal = engulfing.DetectEngulfing(Symbol(), HigherTimeframe);
    
    // Engulfing must align with bias
    if(signal == bias)
        return signal;
    
    return 0;
}

//+------------------------------------------------------------------+
// Step 3: Confirm with Market Structure
//+------------------------------------------------------------------+
bool ConfirmMarketStructure(int signal)
{
    if(!UseStructureFilter)
        return true;
    
    // Check for break of structure or liquidity sweep on mid timeframe
    bool bos = smc.CheckBreakOfStructure(Symbol(), MidTimeframe, signal);
    bool liquiditySweep = smc.CheckLiquiditySweep(Symbol(), MidTimeframe, signal);
    
    return (bos || liquiditySweep);
}

//+------------------------------------------------------------------+
// Step 4: Check for Liquidity Sweep
//+------------------------------------------------------------------+
bool CheckLiquiditySweep(int signal)
{
    if(!UseLiquiditySweepFilter)
        return true;
    
    return smc.CheckLiquiditySweep(Symbol(), MidTimeframe, signal);
}

//+------------------------------------------------------------------+
// Step 5: Calculate Entry, Stop Loss, and Take Profit
//+------------------------------------------------------------------+
bool CalculateEntryLevels(int signal, double &entryPrice, double &stopLoss, double &takeProfit)
{
    // Entry at engulfing close or on structure break
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    int copied = CopyRates(Symbol(), ExecutionTimeframe, 0, 5, rates);
    if(copied < 5)
        return false;
    
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    
    if(signal == 1) // Bullish
    {
        entryPrice = ask;
        stopLoss = rates[0].low - (2 * SymbolInfoDouble(Symbol(), SYMBOL_POINT));
        
        // TP at next resistance or 3x risk
        double risk = entryPrice - stopLoss;
        takeProfit = entryPrice + (risk * MinRiskReward);
    }
    else // Bearish
    {
        entryPrice = bid;
        stopLoss = rates[0].high + (2 * SymbolInfoDouble(Symbol(), SYMBOL_POINT));
        
        // TP at next support or 3x risk
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
    
    if(signal == 1) // Buy
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
    else // Sell
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
