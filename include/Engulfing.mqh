//+------------------------------------------------------------------+
//| Engulfing Pattern Detection Library                              |
//| Identifies bullish/bearish engulfing candles                    |
//+------------------------------------------------------------------+
#ifndef __ENGULFING_MQH__
#define __ENGULFING_MQH__

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
    
    // Detect engulfing pattern: 1 = Bullish, -1 = Bearish, 0 = None
    int DetectEngulfing(string sym, ENUM_TIMEFRAMES tf)
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        int copied = CopyRates(sym, tf, 0, 3, rates);
        if(copied < 3)
            return 0;
        
        // Current candle (index 0), Previous candle (index 1)
        double prev_open = rates[1].open;
        double prev_close = rates[1].close;
        double prev_high = rates[1].high;
        double prev_low = rates[1].low;
        
        double curr_open = rates[0].open;
        double curr_close = rates[0].close;
        double curr_high = rates[0].high;
        double curr_low = rates[0].low;
        
        // Bullish Engulfing: Current candle body engulfs previous candle body
        if(curr_open < prev_close && curr_close > prev_open && curr_close > prev_close)
        {
            return 1; // Bullish
        }
        
        // Bearish Engulfing: Current candle body engulfs previous candle body
        if(curr_open > prev_close && curr_close < prev_open && curr_close < prev_close)
        {
            return -1; // Bearish
        }
        
        // OC Engulfing (Open-Close) variants
        if(curr_close > curr_open && curr_close > prev_close && curr_open < prev_open)
        {
            return 1; // Bullish OC
        }
        
        if(curr_close < curr_open && curr_close < prev_close && curr_open > prev_open)
        {
            return -1; // Bearish OC
        }
        
        return 0; // No engulfing
    }
    
    // Check if engulfing has failed (price doesn't continue in expected direction)
    bool CheckEngulfingFailure(string sym, ENUM_TIMEFRAMES tf, int engulfingSignal)
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        int copied = CopyRates(sym, tf, 0, 3, rates);
        if(copied < 3)
            return false;
        
        double engulf_close = rates[1].close;
        double curr_close = rates[0].close;
        
        if(engulfingSignal == 1) // Bullish engulfing failed
        {
            return curr_close < engulf_close;
        }
        else if(engulfingSignal == -1) // Bearish engulfing failed
        {
            return curr_close > engulf_close;
        }
        
        return false;
    }
    
    // Get engulfing zone boundaries
    void GetEngulfingZone(string sym, ENUM_TIMEFRAMES tf, double &upper, double &lower)
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        int copied = CopyRates(sym, tf, 0, 2, rates);
        if(copied < 2)
            return;
        
        upper = MathMax(rates[1].high, rates[0].high);
        lower = MathMin(rates[1].low, rates[0].low);
    }
};

#endif
