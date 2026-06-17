//+------------------------------------------------------------------+
//| Risk Management Library                                          |
//| Position sizing, stop loss, take profit calculations            |
//+------------------------------------------------------------------+
#ifndef __RISK_MANAGEMENT_MQH__
#define __RISK_MANAGEMENT_MQH__

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
        
        // Get symbol lot constraints
        minLotSize = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
        maxLotSize = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
        lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    }
    
    // Calculate position size based on risk
    double CalculateVolume(double entryPrice, double stopLossPrice)
    {
        if(entryPrice == 0 || stopLossPrice == 0)
            return 0;
        
        // Risk amount in account currency
        double riskAmount = accountBalance * (riskPercent / 100.0);
        
        // Pips at risk
        double pipsRisk = MathAbs(entryPrice - stopLossPrice) / SymbolInfoDouble(Symbol(), SYMBOL_POINT);
        
        if(pipsRisk == 0)
            return 0;
        
        // Tick value
        double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
        
        if(tickValue == 0)
            return 0;
        
        // Calculate lot size
        double volume = riskAmount / (pipsRisk * tickValue);
        
        // Ensure within limits
        if(volume < minLotSize)
            volume = minLotSize;
        if(volume > maxLotSize)
            volume = maxLotSize;
        
        // Round to lot step
        volume = MathFloor(volume / lotStep) * lotStep;
        
        return volume;
    }
    
    // Calculate Risk-to-Reward ratio
    double CalculateRR(double entry, double tp, double sl)
    {
        double risk = MathAbs(entry - sl);
        double reward = MathAbs(tp - entry);
        
        if(risk == 0)
            return 0;
        
        return reward / risk;
    }
    
    // Calculate Stop Loss based on recent swing
    double CalculateSLFromSwing(string sym, ENUM_TIMEFRAMES tf, int direction)
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        int copied = CopyRates(sym, tf, 0, 20, rates);
        if(copied < 20)
            return 0;
        
        if(direction == 1) // Bullish - SL below swing low
        {
            double swing_low = rates[0].low;
            for(int i = 1; i < 20; i++)
            {
                if(rates[i].low < swing_low)
                    swing_low = rates[i].low;
            }
            return swing_low - (5 * SymbolInfoDouble(sym, SYMBOL_POINT));
        }
        else // Bearish - SL above swing high
        {
            double swing_high = rates[0].high;
            for(int i = 1; i < 20; i++)
            {
                if(rates[i].high > swing_high)
                    swing_high = rates[i].high;
            }
            return swing_high + (5 * SymbolInfoDouble(sym, SYMBOL_POINT));
        }
    }
    
    // Calculate Take Profit with multiple levels
    void CalculateTPLevels(double entry, double sl, double &tp1, double &tp2, double &tp3)
    {
        double risk = MathAbs(entry - sl);
        
        tp1 = entry + (risk * 1.5); // 1:1.5 RR
        tp2 = entry + (risk * 3.0); // 1:3 RR
        tp3 = entry + (risk * 5.0); // 1:5 RR
    }
    
    // Update account balance
    void UpdateBalance(double newBalance)
    {
        accountBalance = newBalance;
    }
    
    // Get current account balance
    double GetBalance()
    {
        return AccountInfoDouble(ACCOUNT_BALANCE);
    }
    
    // Get equity
    double GetEquity()
    {
        return AccountInfoDouble(ACCOUNT_EQUITY);
    }
    
    // Get free margin
    double GetFreeMargin()
    {
        return AccountInfoDouble(ACCOUNT_FREEMARGIN);
    }
};

#endif
