defmodule CampaignTool.Entities.Types.StringListTest do
  use ExUnit.Case
  alias CampaignTool.Entities.Types.StringList

  test "cast from list of strings" do
    assert {:ok, ["a", "b"]} = StringList.cast(["a", "b"])
  end

  test "cast nil returns empty list" do
    assert {:ok, []} = StringList.cast(nil)
  end

  test "cast non-list returns error" do
    assert :error = StringList.cast("not a list")
  end

  test "dump encodes list to JSON string" do
    assert {:ok, json} = StringList.dump(["a", "b"])
    assert Jason.decode!(json) == ["a", "b"]
  end

  test "dump empty list" do
    assert {:ok, "[]"} = StringList.dump([])
  end

  test "load decodes JSON string to list" do
    assert {:ok, ["a", "b"]} = StringList.load(~s(["a","b"]))
  end

  test "load nil returns empty list" do
    assert {:ok, []} = StringList.load(nil)
  end

  test "load invalid JSON returns error" do
    assert :error = StringList.load("not json")
  end
end
