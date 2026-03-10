defmodule DungeonCaster.MarkdownTest do
  use ExUnit.Case, async: true
  alias DungeonCaster.Markdown

  describe "render/1" do
    test "renders plain markdown to HTML" do
      html = Markdown.render("Hello **world**")
      assert html =~ "<strong>world</strong>"
    end

    test "converts entity refs to badge spans" do
      html = Markdown.render("Meet ~[Elara]{npc:elara-moonwhisper} at the tavern.")
      assert html =~ ~s(<span class="entity-badge")
      assert html =~ ~s(data-ref="npc:elara-moonwhisper")
      assert html =~ ~s(data-display="Elara")
      assert html =~ ~s(phx-click="open_entity_popover")
      assert html =~ ~s(phx-value-ref="npc:elara-moonwhisper")
      assert html =~ "Elara"
    end

    test "converts multiple entity refs in the same text" do
      html = Markdown.render("~[Elara]{npc:elara} and ~[Ironveil]{location:ironveil}")
      assert html =~ ~s(data-ref="npc:elara")
      assert html =~ ~s(data-ref="location:ironveil")
    end

    test "leaves plain ~ alone (space after ~)" do
      html = Markdown.render("~ this is not a ref")
      refute html =~ "entity-badge"
    end

    test "handles empty string" do
      assert Markdown.render("") == ""
    end

    test "render/1 handles nil" do
      assert Markdown.render(nil) == ""
    end

    test "escapes HTML-special characters in name and ref" do
      html = Markdown.render(~s(~[O'Brien & Co.]{npc:o-brien}))
      assert html =~ "entity-badge"
      # name with & should be escaped in output
      assert html =~ "&amp;"
    end
  end

  describe "extract_entity_refs/1" do
    test "extracts refs from markdown" do
      refs = Markdown.extract_entity_refs("~[Elara]{npc:elara} went to ~[Ironveil]{location:ironveil}")
      assert length(refs) == 2
      assert %{type: "npc", id: "elara", display_name: "Elara"} in refs
      assert %{type: "location", id: "ironveil", display_name: "Ironveil"} in refs
    end

    test "deduplicates refs by type:id" do
      refs = Markdown.extract_entity_refs("~[Elara]{npc:elara} and ~[Elara Again]{npc:elara}")
      assert length(refs) == 1
    end

    test "returns empty list for no refs" do
      assert Markdown.extract_entity_refs("plain text") == []
    end

    test "returns empty list for empty string" do
      assert Markdown.extract_entity_refs("") == []
    end
  end
end
