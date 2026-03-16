defmodule StockAnalysis.TechnicalIndicators do
  @moduledoc """
  Pure computation module for technical indicators from OHLCV data.

  All functions take lists with most-recent data first (matching `Massive.get_daily/1`
  sort order). Returns `nil` when there is insufficient data.

  No API calls, no side effects.
  """

  @doc """
  Wilder's Smoothed RSI from a list of close prices (most recent first).

  Returns a float in [0, 100] or nil if fewer than `period + 1` prices are given.
  """
  def rsi(closes, period \\ 14)
  def rsi(closes, period) when length(closes) < period + 1, do: nil

  def rsi(closes, period) do
    # Take up to 2x period + 1 prices for a stable value
    relevant = Enum.take(closes, period * 2 + 1)

    # Compute changes oldest→newest
    changes =
      relevant
      |> Enum.reverse()
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> b - a end)

    if length(changes) < period do
      nil
    else
      # Seed: average gain/loss from first `period` changes
      {seed_gains, seed_losses} =
        changes
        |> Enum.take(period)
        |> Enum.reduce({0.0, 0.0}, fn ch, {g, l} ->
          if ch > 0, do: {g + ch, l}, else: {g, l + abs(ch)}
        end)

      avg_gain = seed_gains / period
      avg_loss = seed_losses / period

      # Wilder's smoothing for remaining changes
      rest = Enum.drop(changes, period)

      {final_gain, final_loss} =
        Enum.reduce(rest, {avg_gain, avg_loss}, fn ch, {ag, al} ->
          gain = if ch > 0, do: ch, else: 0.0
          loss = if ch < 0, do: abs(ch), else: 0.0
          {(ag * (period - 1) + gain) / period, (al * (period - 1) + loss) / period}
        end)

      if final_loss == 0.0 do
        100.0
      else
        rs = final_gain / final_loss
        Float.round(100.0 - 100.0 / (1.0 + rs), 4)
      end
    end
  end

  @doc """
  Simple moving average of the first `period` entries (most recent `period` prices).

  Returns a float or nil if fewer than `period` prices are given.
  """
  def sma(closes, period)
  def sma(closes, period) when length(closes) < period, do: nil

  def sma(closes, period) do
    closes
    |> Enum.take(period)
    |> then(fn slice -> Enum.sum(slice) / period end)
  end

  @doc """
  MACD with EMA(fast), EMA(slow), and EMA(signal) of the MACD line.

  Returns `%{macd: float, signal: float, histogram: float}` or nil.
  Requires at least `slow + signal_period` close prices.
  """
  def macd(closes, fast \\ 12, slow \\ 26, signal_period \\ 9)
  def macd(closes, _fast, slow, signal_period) when length(closes) < slow + signal_period, do: nil

  def macd(closes, fast, slow, signal_period) do
    ema_fast = ema_series(closes, fast)
    ema_slow = ema_series(closes, slow)

    if is_nil(ema_fast) or is_nil(ema_slow) do
      nil
    else
      min_len = min(length(ema_fast), length(ema_slow))

      macd_line =
        Enum.zip(Enum.take(ema_fast, min_len), Enum.take(ema_slow, min_len))
        |> Enum.map(fn {f, s} -> f - s end)

      sig = ema_from_list(macd_line, signal_period)

      if is_nil(sig) do
        nil
      else
        macd_val = List.first(macd_line)
        hist = macd_val - sig

        %{
          macd: Float.round(macd_val, 4),
          signal: Float.round(sig, 4),
          histogram: Float.round(hist, 4)
        }
      end
    end
  end

  @doc """
  Bollinger Bands with `period`-day SMA ± `multiplier` standard deviations.

  Returns `%{upper: float, middle: float, lower: float}` or nil.
  """
  def bbands(closes, period \\ 20, multiplier \\ 2.0)
  def bbands(closes, period, _mult) when length(closes) < period, do: nil

  def bbands(closes, period, mult) do
    slice = Enum.take(closes, period)
    mean = Enum.sum(slice) / period
    variance = Enum.reduce(slice, 0.0, fn c, acc -> acc + (c - mean) * (c - mean) end) / period
    std = :math.sqrt(variance)

    %{
      upper: Float.round(mean + mult * std, 4),
      middle: Float.round(mean, 4),
      lower: Float.round(mean - mult * std, 4)
    }
  end

  @doc """
  Fast/slow stochastic oscillator (%K and %D).

  Returns `%{k: float, d: float}` or nil.
  All three lists (highs, lows, closes) must be most-recent first and aligned.
  """
  def stoch(highs, lows, closes, k_period \\ 14, d_period \\ 3)

  def stoch(highs, lows, closes, k_period, d_period) do
    needed = k_period + d_period - 1

    if length(closes) < needed or length(highs) < needed or length(lows) < needed do
      nil
    else
      # Compute %K for the most recent d_period positions (offset 0 = most recent)
      k_values =
        0..(d_period - 1)
        |> Enum.map(fn offset ->
          c = Enum.at(closes, offset)
          h_slice = highs |> Enum.drop(offset) |> Enum.take(k_period)
          l_slice = lows |> Enum.drop(offset) |> Enum.take(k_period)
          highest_high = Enum.max(h_slice)
          lowest_low = Enum.min(l_slice)

          if highest_high == lowest_low do
            50.0
          else
            (c - lowest_low) / (highest_high - lowest_low) * 100.0
          end
        end)

      k = List.first(k_values)
      d = Enum.sum(k_values) / d_period
      %{k: Float.round(k, 4), d: Float.round(d, 4)}
    end
  end

  ## Private helpers

  # Returns a list of EMAs most-recent first, seeded by SMA.
  # Produces length(values) - period + 1 elements.
  defp ema_series(values, period) when length(values) < period, do: nil

  defp ema_series(values, period) do
    reversed = Enum.reverse(values)
    seed = reversed |> Enum.take(period) |> then(fn s -> Enum.sum(s) / period end)
    k = 2.0 / (period + 1)
    rest = Enum.drop(reversed, period)

    # Build accumulator oldest→newest; prepending gives most-recent-first result
    Enum.reduce(rest, [seed], fn price, [prev | _] = acc ->
      [price * k + prev * (1 - k) | acc]
    end)
  end

  # Returns the single most-recent EMA value from a list (most-recent first).
  defp ema_from_list(values, period) when length(values) < period, do: nil

  defp ema_from_list(values, period) do
    reversed = Enum.reverse(values)
    seed = reversed |> Enum.take(period) |> then(fn s -> Enum.sum(s) / period end)
    k = 2.0 / (period + 1)
    rest = Enum.drop(reversed, period)
    Enum.reduce(rest, seed, fn price, prev -> price * k + prev * (1 - k) end)
  end
end
