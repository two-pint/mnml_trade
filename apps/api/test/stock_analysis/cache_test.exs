defmodule StockAnalysis.CacheTest do
  use ExUnit.Case, async: false

  alias StockAnalysis.Cache

  # Cache is started with the application; use unique keys per test to avoid collisions

  describe "put/get" do
    test "returns value immediately after put" do
      Cache.put("k", "value", 60)
      assert Cache.get("k") == "value"
    end

    test "returns nil for missing key" do
      assert Cache.get("nonexistent") == nil
    end

    test "two different keys are independent" do
      Cache.put("k1", "v1", 60)
      Cache.put("k2", "v2", 60)
      assert Cache.get("k1") == "v1"
      assert Cache.get("k2") == "v2"
    end
  end

  describe "TTL expiry" do
    # We use Process.sleep here to wait for wall-clock time (TTL expiry), not for a process.
    # The project guideline to use Process.monitor applies to waiting for process termination.
    test "returns nil after TTL expires" do
      Cache.put("ttl_key", "v", 2)
      assert Cache.get("ttl_key") == "v"
      Process.sleep(2_500)
      assert Cache.get("ttl_key") == nil
    end
  end

  describe "delete" do
    test "get returns nil after delete" do
      Cache.put("del_key", "v", 60)
      assert Cache.get("del_key") == "v"
      Cache.delete("del_key")
      assert Cache.get("del_key") == nil
    end
  end

  describe "exists?" do
    test "returns true when key exists and not expired" do
      Cache.put("ex_key", "v", 60)
      assert Cache.exists?("ex_key") == true
    end

    test "returns false when key missing" do
      assert Cache.exists?("missing") == false
    end

    test "returns false when key expired" do
      Cache.put("ex_exp", "v", 2)
      Process.sleep(2_500)
      assert Cache.exists?("ex_exp") == false
    end
  end

  describe "key/3" do
    test "builds key from scope, ticker, data_type" do
      assert Cache.key("stocks", "AAPL", "price") == "stocks:AAPL:price"
      assert Cache.key("analysis", "MSFT", "technical") == "analysis:MSFT:technical"
    end
  end

  describe "default_ttl/1" do
    test "returns configured default for known type" do
      assert Cache.default_ttl(:price) == 15
      assert Cache.default_ttl(:technical) == 3600
      assert Cache.default_ttl(:institutional) == 3600
    end

    test "returns 3600 for unknown type" do
      assert Cache.default_ttl(:unknown) == 3600
    end
  end
end
