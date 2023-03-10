//+------------------------------------------------------------------+
//|                                           Uko_Sup_Rest_Level.mq5 |
//|                                       Copyright 2019, Udo Köller |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, www.lumtu.de"
#property link      "https://github.com/lumtu/i2CT.git"
#property version   "1.00"
#property indicator_chart_window


#include <ChartObjects\ChartObjectsTxtControls.mqh>

input ENUM_TIMEFRAMES InpHTF = PERIOD_H4; // Timeframe für den Prev Bar
input int InpAtr=15;
input double InpDojiBody = 0.15; // Doji-Body in Percent 0.01 to 1 (0.15 default);

input group "Currency Pairs";
input string InpEUR = "EURUSD,EURGBP,EURJPY,EURAUD"; // EUR pairs
input string InpGBP = "GBPUSD,GBPJPY,GBPCHF,GBPAUD ,GBPCAD"; // GBP pairs
input string InpUSD = "USDJPY,USDCAD,USDCHF,EURUSD,GBPUSD,"; // USD pairs
input string InpAUD = "AUDUSD,AUDJPY,AUDCHF,EURAUD,GBPAUD"; // AUD pairs
input string InpCHF = "CHFJPY,EURCHF,USDCHF,CADCHF"; // CHF pairs


int g_xOffset = 400;

CChartObjectLabel m_label[]; 
string symbols[];


class CandleRange{
private:
    string m_symbol;
    ENUM_TIMEFRAMES m_period;
    int m_size;
    MqlRates m_rates[];
    bool m_userBody;
    double m_dojiBody;
public:
    CandleRange(string symbol, ENUM_TIMEFRAMES period, int size)
     : m_symbol(symbol)
     , m_period(period)
     , m_size(size)
     , m_userBody(true)
     , m_dojiBody(0.15)
    {
        RefreshRates();
    }

    void DojiBody(double val) { m_dojiBody = val; }
    double DojiBody() const { return m_dojiBody; }

    bool RefreshRates(){
        return CopyRates(m_symbol, m_period, 1, m_size, m_rates) == m_size;
    }
    
    double Atr() {
        double range = 0.0;
        
        for(int i=0; i<m_size-1; ++i) {
            double high = High(i);
            double low  = Low(i);
            range += high - low;
        }
        
        range = range / (double)(m_size-1);
        
        double lastRange = High(m_size-1) - Low(m_size-1);
        
        //     range = 100
        // lastRange = ?
        
        double atr = (lastRange * 100.0 / range) / 100.0;
        PrintFormat("%.1f", atr);
        return atr;
    }
    
    bool IsDoji() const {
        int idx = m_size-1;
        double open = m_rates[idx].open;
        double close = m_rates[idx].close;
        double high = m_rates[idx].high;
        double low = m_rates[idx].low;
        double sizeBody = MathAbs(open - close);
        double sizeBar = (high - low);
        return (sizeBody <= m_dojiBody * sizeBar);
    }
    
    bool IsGreen() {
        int idx = m_size-1;
        double open = m_rates[idx].open;
        double close = m_rates[idx].close;
        return open < close;
    }
    
    int BodyInPerc() {
        int idx = m_size-1;
        double open = m_rates[idx].open;
        double close = m_rates[idx].close;
        double high = m_rates[idx].high;
        double low = m_rates[idx].low;
        double sizeBody = MathAbs(open - close);
        double sizeBar = (high - low);

        return (int)MathFloor(sizeBody * 100.0 / sizeBar);
    }
    
private:
    double High(int idx) {
        double high = m_rates[idx].high;
        if(m_userBody) {
            high = MathMax(m_rates[idx].open, m_rates[idx].close);
        }
        return high;
    }
    double Low(int idx) {
        double low  = m_rates[idx].low;
        if(m_userBody) {
            low  = MathMin(m_rates[idx].open, m_rates[idx].close);
        }
        return low;
    }
};


int OnInit()
{
    InitLabels();
    return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason)
{
}


int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    
    if(rates_total-prev_calculated>10) {
        Calculate();
        return rates_total;
    }


    if(prev_calculated<rates_total)
    {
        Calculate();
    }
   
    return(rates_total);

}



void Calculate()
{
    
    int size = ArraySize(symbols);
    for(int i=0;i<size;i++) {
        CandleRange htf_cr(symbols[i], InpHTF, InpAtr);
        CandleRange ctf_cr(symbols[i], _Period, InpAtr);
        
        double htf_atr = -1;
        int htf_body = 0;
        uint htf_clr = clrLightGray;

        double ctf_atr = -1;
        int ctf_body = 0;
        string ctf_up_down = "--";
        
        if(htf_cr.RefreshRates()) {
            htf_atr = htf_cr.Atr();
            htf_body = htf_cr.BodyInPerc();
            htf_clr = htf_cr.IsGreen() ? clrGreen : clrRed;
        }
        
        if(ctf_cr.RefreshRates()) {
            ctf_atr = ctf_cr.Atr();
            ctf_body = ctf_cr.BodyInPerc();
            ctf_up_down = ctf_cr.IsGreen() ? "/\\": "\\/";
        }
        
        m_label[i].Description( StringFormat("%s|B:%d%|A:%.1f | CTF|%s|B:%d%|A:%.1f", symbols[i], htf_body , htf_atr, ctf_up_down, ctf_body, ctf_atr) );
        m_label[i].Color(htf_clr);
        
    }
}


void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{

    if(id == CHARTEVENT_CHART_CHANGE)
    {
        long chartId = ChartID();
        if( ChartGetInteger(chartId, CHART_WINDOW_HANDLE,0) != 0)
        {
            int size = ArraySize(m_label);
            int charWidth =(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
            charWidth = 500;
            for(int i=0;i<size;i++)
              {
               m_label[i].X_Distance(charWidth-g_xOffset);
              }
            return;
        }

    }
}

bool IsDoji(double high, double low, double open, double close)
{
   const double DOJI_PCT = InpDojiBody; // Assume 3% or less body size for Doji

   const double sizeBody = MathAbs(open - close);
   const double sizeBar = (high - low);
   return (sizeBody <= DOJI_PCT * sizeBar);
}


void InitLabels()
{
   int charWidth =(int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   string subSymb = StringSubstr(_Symbol, 0, 3);
   int sy=50;
   int dy=16;

   string symMap[];
   if("EUR" == subSymb) {
      StringSplit(InpEUR, (ushort)',', symMap);
      
   } else if("GBP" == subSymb) {
      StringSplit(InpGBP, (ushort)',', symMap);
      
   } else if("USD" == subSymb) {
      StringSplit(InpUSD, (ushort)',', symMap);
      
   } else if("AUD" == subSymb) {
      StringSplit(InpAUD, (ushort)',', symMap);
      
   } else if("CHF" == subSymb) {
      StringSplit(InpCHF, (ushort)',', symMap);
   }
   
   ArrayResize(symbols, 1);
   symbols[0] = _Symbol;
   
   for(int i=0; i<ArraySize(symMap); ++i) {
      StringTrimLeft ( symMap[i] );
      StringTrimRight( symMap[i] );
      string sym = symMap[i];

      if(sym == _Symbol)
         continue;

      bool isCustom = false;
      if( !SymbolExist(sym, isCustom) ) {
         continue;
      }
      
      if(isCustom) {
         continue;
      }
      
      
      int n = ArraySize(symbols);
      ArrayResize(symbols, n+1);
      symbols[n] = sym;
   }
   
   
   for(int i=0; i<ArraySize(symbols); ++i) {
      int lSize = ArraySize(m_label );
      ArrayResize(m_label, lSize+1);
      m_label[lSize].Create(0, symbols[i], 0, charWidth-g_xOffset, sy+dy*lSize);
      m_label[lSize].Font("Consolas");
      m_label[lSize].Color(clrLightGray);
      m_label[lSize].FontSize(10);
      m_label[lSize].Description(symbols[i]);

   }
   ChartRedraw();
}