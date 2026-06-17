//+------------------------------------------------------------------+
//| Smart Money Context Library                                      |
//| Market structure, liquidity sweeps, break of structure          |
//+------------------------------------------------------------------+
#ifndef __SMC_MQH__
#define __SMC_MQH__

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
    
    // Check for Break of Structure (BOS)
    bool CheckBreakOfStructure(string sym, ENUM_TIMEFRAMES tf, int direction)
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        int copied = CopyRates(sym, tf, 0, 10, rates);
        if(copied < 10)
            return false;
        
        // Bullish BOS: Price breaks previous high
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
        
        // Bearish BOS: Price breaks previous low
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
    
    // Check for Liquidity Sweep (LS)
    bool CheckLiquiditySweep(string sym, ENUM_TIMEFRAMES tf, int direction)
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        int copied = CopyRates(sym, tf, 0, 20, rates);
        if(copied < 20)
            return false;
        
        // Find swing highs and lows
        double swing_high = rates[10].high;
        double swing_low = rates[10].low;
        
        for(int i = 5; i < 15; i++)
        {
            if(rates[i].high > swing_high)
                swing_high = rates[i].high;
            if(rates[i].low < swing_low)
                swing_low = rates[i].low;
        }
        
        // Bullish LS: Price sweeps below recent low, then reverses up
        if(direction == 1)
        {
            bool swept_low = rates[2].low < swing_low;
            bool reversing_up = rates[0].close > rates[1].close;
            return swept_low && reversing_up;
        }
        
        // Bearish LS: Price sweeps above recent high, then reverses down
        if(direction == -1)
        {
            bool swept_high = rates[2].high > swing_high;
            bool reversing_down = rates[0].close < rates[1].close;
            return swept_high && reversing_down;
        }
        
        return false;
    }
    
    // Fair Value Gap (FVG) detection
    bool CheckFVG(string sym, ENUM_TIMEFRAMES tf, int &direction)
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        int copied = CopyRates(sym, tf, 0, 3, rates);
        if(copied < 3)
            return false;
        
        // Bullish FVG: gap between candle 2 low and candle 0 high
        if(rates[2].low > rates[0].high)
        {
            direction = 1;
            return true;
        }
        
        // Bearish FVG: gap between candle 2 high and candle 0 low
        if(rates[2].high < rates[0].low)
        {
            direction = -1;
            return true;
        }
        
        return false;
    }
    
    // Market Structure Shift (MSS)
    bool CheckMarketStructureShift(string sym, ENUM_TIMEFRAMES tf)
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        int copied = CopyRates(sym, tf, 0, 10, rates);
        if(copied < 10)
            return false;
        
        // Bullish MSS: Higher lows and higher highs
        bool bullish_mss = true;
        for(int i = 1; i < 5; i++)
        {
            if(rates[i].low < rates[i+1].low || rates[i].high < rates[i+1].high)
            {
                bullish_mss = false;
                break;
            }
        }
        
        // Bearish MSS: Lower highs and lower lows
        bool bearish_mss = true;
        for(int i = 1; i < 5; i++)
        {
            if(rates[i].high > rates[i+1].high || rates[i].low > rates[i+1].low)
            {
                bearish_mss = false;
                break;
            }
        }
        
        return bullish_mss || bearish_mss;
    }
    
    // Displacement (Candle directional move)
    double GetDisplacementPercent(string sym, ENUM_TIMEFRAMES tf)
    {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        int copied = CopyRates(sym, tf, 0, 1, rates);
        if(copied < 1)
            return 0;
        
        if(rates[0].open == 0)
            return 0;
        
        double displacement = ((rates[0].close - rates[0].open) / rates[0].open) * 100;
        return displacement;
    }
};

#endif
