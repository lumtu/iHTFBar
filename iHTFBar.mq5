//+------------------------------------------------------------------+
//|                                                      iHTFBar.mq5 |
//|                                       Copyright 2022, Udo Köller |
//|                                         https://github.com/lumtu |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, www.lumtu.de"
#property link      "https://github.com/lumtu/iHTFBar.git"
#property version   "1.00"
#property indicator_chart_window


#include <Canvas\Canvas.mqh>
#include <Controls\Rect.mqh>
#include <Generic\HashMap.mqh>

enum EnSide {
    Overlay,
    Left,
    Right
};

class CounterPair {
public:
    long Up;
    long Down;
    CounterPair()
    : Up(0)
    , Down(0)
    {}
    
    void Increment(bool isUp) {
        if(isUp) Up++;
        else Down++;
    }
};


input ENUM_TIMEFRAMES InpHTF = PERIOD_H4; // Timeframe für den Prev Bar
input EnSide InpSide = EnSide::Right;

const int CHART_WINDOW = 0;
CCanvas   ExtCanvas;
CRect     area;

double    PriceHTFOpen  = 0.0;
double    PriceHTFClose = 0.0;
CHashMap<int, int> CounterMap; 

long oldScaleValue = -1;
double oldMinPrice = 0;
double oldMaxPrice = 0;

long counter = 1;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{

   CounterMap.Clear();
  
   IndicatorSetString(INDICATOR_SHORTNAME, "iHTFBar Indicator" );

   int width =(int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int height=(int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   area.SetBound(0, 0, width, height);

   string id = IntegerToString((int)TimeLocal());

   string name = "iHTFBar-svg." +id ;
   if(!ExtCanvas.CreateBitmapLabel(0,0, name, area.left, area.top, area.Width()+1, area.Height()+1, COLOR_FORMAT_ARGB_NORMALIZE))
   {
      Print("---- ERROR : init Canvas -----");
      return(INIT_FAILED);
   }
   ObjectSetInteger(0,name,OBJPROP_ZORDER,-100);
   
   ObjectSetInteger(0,name,OBJPROP_BACK, 1);
   
   CalcProfile();
   DrawProfil();

   return(INIT_SUCCEEDED);
}
  
void OnDeinit(const int reason)
{
   ExtCanvas.Destroy();
   
   CounterMap.Clear();
}  
  
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    
    if(id == CHARTEVENT_CHART_CHANGE)
    {
        long chartId = ChartID();
        if( ChartGetInteger(chartId,CHART_WINDOW_HANDLE,0) == 0)
        {
            return;
        }

        long newScale = ChartGetInteger(chartId,CHART_SCALE,0);
        double min = ChartGetDouble(chartId, CHART_PRICE_MIN, 0);
        double max = ChartGetDouble(chartId, CHART_PRICE_MAX, 0);

        if(oldScaleValue != newScale ||
            oldMinPrice != min ||
            oldMaxPrice != max )
        {
            // PrintFormat("Scale %d", newScale );
            oldScaleValue = newScale;
            oldMinPrice = min;
            oldMaxPrice = max;
            
            CalcProfile();
            DrawProfil();
        }
    }
   
}  
  
  
    
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
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
    
    if(rates_total-prev_calculated>10)
        return rates_total;
        
    if(prev_calculated<rates_total)
    {
        PrintFormat("%-3d Iteration ", counter);
        CalcProfile();
        DrawProfil();      
    }
   
    return(rates_total);
}
//+------------------------------------------------------------------+




//+------------------------------------------------------------------+
//| 
//+------------------------------------------------------------------+
void CalcProfile_()
{
    CounterMap.Clear();
    
    MqlRates rates_array[2];
    if( CopyRates(_Symbol, InpHTF, 0, 2, rates_array) == -1) {
        return;
    }
    
    
    datetime datime[3];
    if( CopyTime(_Symbol, InpHTF, 0, 3, datime) == -1) {
        return;
    }
   
    MqlRates rates[];
    int rates_count = CopyRates(_Symbol, PERIOD_M1, datime[1], datime[2], rates);
    if (rates_count == -1) { 
        PrintFormat("CopyRates(%s, ...)  failed, error %d", _Symbol, GetLastError() );
            
        return;                                                                                   
    } 
  
    for(int i=0; i<=100; ++i) {
        
        CounterMap.TrySetValue(i, 1);
    }
  
    int digits = MathMin(4, Digits());
    // PrintFormat("Digits : %d", digits);
    double factor = 1.0; // MathPow(10, digits);

    double high = rates_array[0].high;
    double low  = rates_array[0].low;
    double price_diff = high - low;
    double last_price = 0.0;

    for(int i=1; i<rates_count; ++i)
    {
        MqlRates rate = rates[i];
        MqlRates last_rate = rates[i-1];
        
        double o = rate.open;
        double c = rate.close;
        // double o = rate.open;
        // double o = rate.open;
       
        // Preis in Prozent
        int percent = (int)MathRound((o-low) * 100.0 /  price_diff);
        IncrementCounter(percent);

        percent = (int)MathRound((c-low) * 100.0 /  price_diff);
        IncrementCounter(percent);
    }
    
    PrintFormat("End of CalcProfile()");

}

void CalcProfile()
{
    CounterMap.Clear();
    
    MqlRates rates_array[2];
    if( CopyRates(_Symbol, InpHTF, 0, 2, rates_array) == -1) {
        return;
    }
    
    
    datetime datime[3];
    if( CopyTime(_Symbol, InpHTF, 0, 3, datime) == -1) {
        return;
    }
   
    MqlTick tick_array[];   // Tick receiving array 
    int ticks = CopyTicksRange(_Symbol,tick_array,COPY_TICKS_ALL,datime[1]*1000,datime[2]*1000);
    if (ticks == -1) { 
        PrintFormat("CopyTicksRange(%s,tick_array,COPY_TICKS_ALL,%s,%s) failed, error %d",        
            _Symbol,TimeToString(datime[2]),TimeToString(datime[1]),GetLastError() );
            
        return;                                                                                   
    } 
  
    for(int i=0; i<=100; ++i) {
        
        CounterMap.TrySetValue(i, 1);
    }
  
    int digits = MathMin(4, Digits());
    // PrintFormat("Digits : %d", digits);
    double factor = 1.0; // MathPow(10, digits);

    double high = rates_array[0].high;
    double low  = rates_array[0].low;
    double price_diff = high - low;
    double last_price = 0.0;
    for(int i=0; i< ticks; ++i)
    {
        bool buy_tick   =((tick_array[i].flags&TICK_FLAG_BUY)==TICK_FLAG_BUY); 
        bool sell_tick  =((tick_array[i].flags&TICK_FLAG_SELL)==TICK_FLAG_SELL); 
        bool ask_tick   =((tick_array[i].flags&TICK_FLAG_ASK)==TICK_FLAG_ASK); 
        bool bid_tick   =((tick_array[i].flags&TICK_FLAG_BID)==TICK_FLAG_BID); 
        bool last_tick  =((tick_array[i].flags&TICK_FLAG_LAST)==TICK_FLAG_LAST); 
        bool volume_tick=((tick_array[i].flags&TICK_FLAG_VOLUME)==TICK_FLAG_VOLUME);     
    
        if(volume_tick )
            continue;

        double last_prev_price = last_price;
        
        if(ask_tick )
            last_price = tick_array[i].ask;
        else if(bid_tick )
            last_price = tick_array[i].bid;
        else if(last_tick )
            last_price = tick_array[i].last;
        else 
            continue;
            
// TICK_FLAG_BUY – der Tick hat als Ergebnis eines Kauf-Deals erschienen
// TICK_FLAG_SELL

        if(i==0) 
            continue;
            
       
        // Preis in Prozent
        int percent = (int)MathRound((high - last_price) * 100.0 /  price_diff);

        
        IncrementCounter(percent);
    }
    
    PrintFormat("End of CalcProfile()");
}

//+------------------------------------------------------------------+

void IncrementCounter(int percent)
{

    if( CounterMap.ContainsKey(percent) )
    {
        int count = 1;
        CounterMap.TryGetValue(percent, count);
        CounterMap.TrySetValue(percent, (count+2));
    }
}

//+------------------------------------------------------------------+
//| 
//+------------------------------------------------------------------+
void DrawProfil()
{
   PrintFormat("DrawProfil : begin");

   int canvasWidth = ExtCanvas.Width();
   uint clrDown = ColorToARGB(XRGB(0, 10, 200), 100);
   uint clrUp = ColorToARGB(XRGB(10, 200, 10), 100);

    MqlRates rates_array[2];
    if( CopyRates(_Symbol, InpHTF, 0, 2, rates_array) == -1) {
        return;
    }

   
    ExtCanvas.Erase();
    
    bool isUp = rates_array[0].open < rates_array[0].close;
    datetime barTime = rates_array[1].time;
    double high = rates_array[0].high;
    double low  = rates_array[0].low;
    double diff = high - low;
   
    // int chartWidth = ChartGetInteger(ChartID(), CHART_WIDTH_IN_PIXELS, 0);
    // int chartBarWidth = ChartGetInteger(ChartID(), CHART_WIDTH_IN_BARS, 0);
   
    int xVal[];
    int yVal[];
   
    int barWidth = 50; // Pixel
    int maxCount = 1;
    
    for(int i=0; i<=100; ++i) {
        int count = 1;
        if(CounterMap.TryGetValue(i, count)) {
            maxCount = MathMax(maxCount, count);
        }
    }
    
    int xlow=0, ylow=0;
    ChartTimePriceToXY(0, 0, barTime, low, xlow, ylow);
    
    double price=0.0;
    uint clr =  (isUp?clrUp:clrDown);
    for(int i=1; i<=100; ++i) {
        int count = 1;
        if(CounterMap.TryGetValue(i, count)) {
        
            // percent To Price
            double last_price = price;
            
            price = low + (i * diff / 100.0);

            if(i<=1) 
                continue;
        
            int lx, ly;
            ChartTimePriceToXY(0, 0, barTime, last_price, lx, ly);
            
            int x, y;
            ChartTimePriceToXY(0, 0, barTime, price, x, y);
            
            
            double width_percent = count * 100.0 / (double)maxCount;
            
            int xOffset = (int) MathFloor(barWidth * (width_percent / 100.0));
            
            ExtCanvas.FillRectangle( x, ly, x+xOffset, y, clr );
        }
    }
   
   ExtCanvas.Update();

   ChartRedraw();

   PrintFormat("DrawProfil : done");
}
//+------------------------------------------------------------------+




