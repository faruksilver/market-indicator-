$OutputPath = "C:\YeniIndikator\veri.json"
Write-Host "API'den anlik fiyatlar cekiliyor..." -ForegroundColor Yellow

function Get-BinancePrice($symbol) {
    try { 
        $url = "https://api.binance.com/api/v3/ticker/price?symbol=$symbol"
        $res = Invoke-RestMethod -Uri $url -UseBasicParsing
        return [math]::Round([double]$res.price, 2)
    } catch { 
        Write-Host "Hata: $symbol cekilemedi" -ForegroundColor Red
        return 0 
    }
}

function Get-BinanceHistory($symbol) {
    try { 
        $url = "https://api.binance.com/api/v3/klines?symbol=$symbol&interval=1d&limit=250"
        $res = Invoke-RestMethod -Uri $url -UseBasicParsing
        $closes = @(); foreach ($k in $res) { $closes += [double]$k[4] }
        return $closes 
    } catch { return $null }
}

$CryptoList = @()
foreach ($c in @("BTCUSDT","ETHUSDT","BNBUSDT","XRPUSDT","SOLUSDT","ADAUSDT","DOGEUSDT","DOTUSDT","AVAXUSDT","LINKUSDT")) { 
    $spotPrice = Get-BinancePrice $c
    $prices = Get-BinanceHistory $c
    
    if ($prices -and $spotPrice -gt 0) {
        # EMA ve RSI Hesaplamalari
        $ema20 = ($prices[-20..-1] | Measure-Object -Average).Average
        $ema50 = ($prices[-50..-1] | Measure-Object -Average).Average
        $ema200 = ($prices[-200..-1] | Measure-Object -Average).Average
        
        $gains = 0; $losses = 0
        for ($i = $prices.Count - 14; $i -lt $prices.Count; $i++) { 
            $diff = $prices[$i] - $prices[$i-1]
            if ($diff -gt 0) { $gains += $diff } else { $losses += [math]::Abs($diff) } 
        }
        $rsi = 100 - (100 / (1 + (($gains/14) / ($losses/14 + 0.0001))))
        
        $cName = $c -replace "USDT",""
        $CryptoList += @{
            Name = $cName; Symbol = $cName; Market = "BINANCE"; Currency = "$"
            Price = $spotPrice
            RSI = [math]::Round($rsi, 1)
            EMA20 = [math]::Round($ema20, 2); EMA50 = [math]::Round($ema50, 2); EMA200 = [math]::Round($ema200, 2)
            BBUpper = [math]::Round($spotPrice * 1.03, 2)  # Basitlestirilmis
            BBLower = [math]::Round($spotPrice * 0.97, 2)  # Basitlestirilmis
            Fib382 = [math]::Round($spotPrice * 0.98, 2); Fib618 = [math]::Round($spotPrice * 0.95, 2)
            LongTarget = [math]::Round($spotPrice * 1.02, 2); LongProb = [math]::Round(50 + ($rsi - 50), 0)
            ShortTarget = [math]::Round($spotPrice * 0.98, 2); ShortProb = [math]::Round(100 - (50 + ($rsi - 50)), 0)
        }
    }
}

$existingData = @{}
if (Test-Path $OutputPath) { try { $existingData = Get-Content $OutputPath -Raw | ConvertFrom-Json } catch {} }

$Data = @{ Crypto = $CryptoList; BIST = $existingData.BIST; DAX = $existingData.DAX; USStocks = $existingData.USStocks; News = $existingData.News }

$Data | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputPath -Encoding utf8
Write-Host "Fiyatlar API'den basariyla guncellendi!" -ForegroundColor Green
