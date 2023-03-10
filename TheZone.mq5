//+------------------------------------------------------------------+
//|                                                         MACD.mq5 |
//|                   Copyright 2009-2020, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "2022-2022, lumtu Software"
#property link        "http://www.lumtu.de"
#property description "UKO Trend"

#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   4
#property indicator_type1   DRAW_ARROW
#property indicator_type2   DRAW_ARROW
#property indicator_type3   DRAW_ARROW
#property indicator_type4   DRAW_ARROW
#property indicator_width1  1
#property indicator_width2  1
#property indicator_width3  1
#property indicator_width4  1
#property indicator_color1  clrRed
#property indicator_color2  clrGreen
#property indicator_color3  Gray
#property indicator_color4  Gray
#property indicator_label1  "Resistance"
#property indicator_label2  "Support"
#property indicator_label3  "doji"
#property indicator_label4  "Entry"

// #include <Indicators/Oscilators.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

input int InpPeriod = 2;  // Anzahl Bars
// input int InpBacklook=50;    // Bar rücksha
input double InpAccurency=75.0; // Genauichkeit

input group "Indicator Stochastic"
input ENUM_TIMEFRAMES InpStoPeriod  = PERIOD_CURRENT; // Periode/Timeframe
input int             InpKPeriod    = 14;             // K-Periode(Anzahl der Bars)
input int             InpDPeriod    =  3;             // Mittelungsperiode 
input int             InpSlowing    =  3;             // Verlangsamung
input ENUM_MA_METHOD  InpMethodMA   = MODE_SMA;       // Mittelungsmethode
input ENUM_STO_PRICE  InpApplied    = STO_CLOSECLOSE; // Preiswahl 
input int             InpLevelLow   = 10; // Ebene unten
input int             InpLevelHigh  = 90; // Ebene oben

input group "Currency Pairs";
input string InpEUR = "EURUSD,EURGBP,EURJPY,EURAUD"; // EUR pairs
input string InpGBP = "GBPUSD,GBPJPY,GBPCHF,GBPAUD ,GBPCAD"; // GBP pairs
input string InpUSD = "USDJPY,USDCAD,USDCHF,EURUSD,GBPUSD,"; // USD pairs
input string InpAUD = "AUDUSD,AUDJPY,AUDCHF,EURAUD,GBPAUD"; // AUD pairs
input string InpCHF = "CHFJPY,EURCHF,USDCHF,CADCHF"; // CHF pairs


double ExtMainBuffer[];
double ExtSignalBuffer[];
double ExtHighesBuffer[];
double ExtLowesBuffer[];

double ExtResistanceBuffer[];
double ExtSupportBuffer[];

double ExtDojiBuffer[];

double ExtEntryBuffer[];

int ExtArrowShift=-30;
double accurency;

int g_stochHandle;

CChartObjectLabel m_label[]; 
string symbols[];


void OnInit()
{
   accurency = MathMin(100.0, InpAccurency);
   accurency = MathMax(10.0, InpAccurency);
   
   PlotIndexSetInteger(0, PLOT_ARROW, 158);
   PlotIndexSetInteger(1, PLOT_ARROW, 158);
   PlotIndexSetInteger(2, PLOT_ARROW, 225);
   PlotIndexSetInteger(3, PLOT_ARROW, 174);
   SetIndexBuffer(0, ExtResistanceBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtSupportBuffer,    INDICATOR_DATA);
   SetIndexBuffer(2, ExtDojiBuffer,       INDICATOR_DATA);
   SetIndexBuffer(3, ExtEntryBuffer,      INDICATOR_DATA);
   
   

   SetIndexBuffer(4, ExtMainBuffer,INDICATOR_DATA);
   SetIndexBuffer(5, ExtSignalBuffer,INDICATOR_DATA);
   SetIndexBuffer(6, ExtHighesBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, ExtLowesBuffer,INDICATOR_CALCULATIONS);
   
   PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, -ExtArrowShift);
   PlotIndexSetInteger(3, PLOT_ARROW_SHIFT,  ExtArrowShift);
   
   ArrayInitialize(ExtDojiBuffer , EMPTY_VALUE);
   ArrayInitialize(ExtEntryBuffer, EMPTY_VALUE);
   
   InitLabels();

}

void InitLabels()
{
   int charWidth =(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
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
      m_label[lSize].Create(0, symbols[i], 0, charWidth-120, sy+dy*lSize);
      m_label[lSize].Font("Monospace");
      m_label[lSize].Color(clrLightGray);
      m_label[lSize].FontSize(10);
      m_label[lSize].Description(symbols[i]);

   }
   ChartRedraw();
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
            for(int i=0;i<size;i++)
              {
               m_label[i].X_Distance(charWidth-120);
              }
            return;
        }

    }
}


void CalcTimeframeContinuity()
{
  
   datetime currTime = TimeCurrent( );
   
   MqlRates rates[];
   
   ENUM_TIMEFRAMES tf = PERIOD_H4;
   
   int size = ArraySize(symbols);
   
   for(int i=0; i<size; ++i)
   {
      if(CopyRates(symbols[i], tf , currTime, 1, rates)==1)
      {
         m_label[i].Description("" + symbols[i] + " H4");
         if(rates[0].open >= rates[0].close ) {
            m_label[i].Color(Red);
         } else {
            m_label[i].Color(Green);
         }
      }
   }


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

   OnCalculateStoch(rates_total, prev_calculated, open, high, low, close );   
   
//---- checking the number of bars for sufficiency for calculation
   if(rates_total<InpPeriod)
      return(0);

   CalcTimeframeContinuity();

   double avgCandleHeight = 0.0;

   int start=prev_calculated-1;
   if(start<1)
   {
      ArrayInitialize(ExtDojiBuffer ,EMPTY_VALUE);
      ArrayInitialize(ExtEntryBuffer,EMPTY_VALUE);
      
      ExtResistanceBuffer[0] = EMPTY_VALUE;
      ExtSupportBuffer[0] = EMPTY_VALUE;
      ExtDojiBuffer[0] = EMPTY_VALUE;
      ExtEntryBuffer[0] = EMPTY_VALUE;
      start=1;
      
      avgCandleHeight=getAvgCandleHeight(rates_total, high, low);
   }


   for(int i=start;i<rates_total;i++)
   {
      int matches=0;
      double matchSumUpper=0.0;
      double matchSumLower=0.0;
      double matchAvgUpper=0.0;
      double matchAvgLower=0.0;
      
      double iUpper = high[i] + avgCandleHeight;
      double iLower = low[i]  - avgCandleHeight;
      
      ExtResistanceBuffer[i] = ExtResistanceBuffer[i-1];
      ExtSupportBuffer[i]    = ExtSupportBuffer[i-1];
      ExtDojiBuffer[i] = EMPTY_VALUE;
      ExtEntryBuffer[i] = EMPTY_VALUE;
      
      
      bool checkEntry = false;
      //--- skip if in middel of stochastic area
      bool isLongCond  = IsStochLongCondition(i);
      bool isShortCond = IsStochShortCondition(i);
      if( !isLongCond && !isShortCond  )
      {
         checkEntry = true;
         // continue;
      }

      //--- skip none doji candles
      if( false == IsDoji(high[i], low[i], open[i], close[i]) )
      {
         checkEntry = true;
         // continue;
      }
      
      if(checkEntry)
      {
         int dojiIdx = -1;
         // letzten Doji suchen
         int idx=rates_total-1;
         for( ; idx > 0 ; --idx )
         {
            if(ExtDojiBuffer[idx] != EMPTY_VALUE)
            {
               dojiIdx = idx;
               break;
            }
         }
         
        
         double dijiRange = high[idx] - low[idx];

         if(   (high[i] > ExtResistanceBuffer[i] && low[i] < ExtResistanceBuffer[i]) 
            || (high[i] > ExtSupportBuffer[i] && low[i] < ExtSupportBuffer[i]) ) 
         {
            
            double currBarRange = MathAbs( open[i] - close[i] );
            if( dijiRange*2 <  currBarRange) {
               // ExtEntryBuffer[i] = high[i];
            }
         }
         // keine weiten auswertungen für Support / Resistence
         continue;
      }
      
      ExtDojiBuffer[i] = low[i];
     
      bool IsWithAccurencyCheck = false;
      if(IsWithAccurencyCheck)
      {
         //--- look back for candles in the same range
         for(int k=i-1;k>=i-InpPeriod && k>=0;k--)
         {
            if(high[k] <= iUpper && low[k] >= iLower)
            {
               matches++;
               matchSumUpper += high[k];
               matchSumLower += low[k];
            }
         }
         
         // --- set new resistance level
         if((double)matches / (double)InpPeriod *100.0 >= accurency )
         {
            matchAvgUpper = matchSumUpper / (double)matches;
            matchAvgLower = matchSumLower / (double)matches;
            if( matchAvgUpper > ExtResistanceBuffer[i] || matchAvgLower < ExtSupportBuffer[i] )
            {
               if(isShortCond)
                  ExtResistanceBuffer[i] = matchAvgUpper + avgCandleHeight;
                  
               if(isLongCond)
                  ExtSupportBuffer[i]    = matchAvgLower - avgCandleHeight;
            }
         }
      }
      else
      {
         iUpper = high[i];
         iLower = low[i];
         double maxUpper = iUpper;
         double maxLower = iLower;
         //--- look back for candles in the same range
         for(int k=i-1; k >= i-20 && k>=0; k--)
         {
            double h1 = MathMax(open[k], close[k]);
            double l1 = MathMin(open[k], close[k]);
            if(h1 <= iUpper && l1 >= iLower)
            {
               matches++;
               maxUpper = MathMax(maxUpper, high[k]);
               maxLower = MathMax(maxLower, low[k]);
            }
            else
            {
               break;
            }
         }
         
         if(isLongCond)
         {
            ExtSupportBuffer[i] = maxLower;
         }
         else if(isShortCond)
         {
            ExtResistanceBuffer[i] = maxUpper;
         }
      }
   }
      
   return rates_total;   
}



double getAvgCandleHeight(const int rates_total,const double &High[],const double &Low[])
  {
   double sum=0.0;
   for(int i=0;i<rates_total-1;i++)
     {
      sum+=High[i]-Low[i];
     }
   return sum/(rates_total-1);
  }

bool IsDoji(double high, double low, double open, double close)
{
   const double DOJI_PCT = 0.15; // Assume 3% or less body size for Doji

   const double sizeBody = MathAbs(open - close);
   const double sizeBar = (high - low);
   return (sizeBody <= DOJI_PCT * sizeBar);
}

bool IsStochLongCondition(int idx)
{
   double signal = ExtSignalBuffer[idx];
   
   if(signal < InpLevelLow)
   {
      return true;
   }
   
   return false;
}

bool IsStochShortCondition(int idx)
{
   double signal = ExtSignalBuffer[idx];
      
   if(signal > InpLevelHigh)
   {
      return true;
   }
   
   return false;
}


//+------------------------------------------------------------------+
//| Stochastic Oscillator                                            |
//+------------------------------------------------------------------+
int OnCalculateStoch(const int rates_total,
                const int prev_calculated,
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[] )
  {
   int i,k,start;
//--- check for bars count
   if(rates_total<=InpKPeriod+InpDPeriod+InpSlowing)
      return(0);
//---
   start=InpKPeriod-1;
   if(start+1<prev_calculated)
      start=prev_calculated-2;
   else
     {
      for(i=0; i<start; i++)
        {
         ExtLowesBuffer[i]=0.0;
         ExtHighesBuffer[i]=0.0;
        }
     }
//--- calculate HighesBuffer[] and ExtHighesBuffer[]
   for(i=start; i<rates_total && !IsStopped(); i++)
     {
      double dmin=1000000.0;
      double dmax=-1000000.0;
      for(k=i-InpKPeriod+1; k<=i; k++)
        {
         if(dmin>low[k])
            dmin=low[k];
         if(dmax<high[k])
            dmax=high[k];
        }
      ExtLowesBuffer[i]=dmin;
      ExtHighesBuffer[i]=dmax;
     }
//--- %K
   start=InpKPeriod-1+InpSlowing-1;
   if(start+1<prev_calculated)
      start=prev_calculated-2;
   else
     {
      for(i=0; i<start; i++)
         ExtMainBuffer[i]=0.0;
     }
//--- main cycle
   for(i=start; i<rates_total && !IsStopped(); i++)
     {
      double sum_low=0.0;
      double sum_high=0.0;
      for(k=(i-InpSlowing+1); k<=i; k++)
        {
         sum_low +=(close[k]-ExtLowesBuffer[k]);
         sum_high+=(ExtHighesBuffer[k]-ExtLowesBuffer[k]);
        }
      if(sum_high==0.0)
         ExtMainBuffer[i]=100.0;
      else
         ExtMainBuffer[i]=sum_low/sum_high*100;
     }
//--- signal
   start=InpDPeriod-1;
   if(start+1<prev_calculated)
      start=prev_calculated-2;
   else
     {
      for(i=0; i<start; i++)
         ExtSignalBuffer[i]=0.0;
     }
   for(i=start; i<rates_total && !IsStopped(); i++)
     {
      double sum=0.0;
      for(k=0; k<InpDPeriod; k++)
         sum+=ExtMainBuffer[i-k];
      ExtSignalBuffer[i]=sum/InpDPeriod;
     }
//--- OnCalculate done. Return new prev_calculated.
   return(rates_total);
  }
//+------------------------------------------------------------------+


