--- Tests for the shared pure-text helpers (poste-ai.text).

describe("poste-ai.text", function()
  local text = require("poste-ai.text")

  describe("truncate", function()
    it("keeps short text unchanged", function()
      assert.equals("hello", text.truncate("hello", 10))
    end)

    it("truncates by display width with an ellipsis", function()
      local result = text.truncate(string.rep("x", 20), 8)
      assert.equals("xxxxx...", result)
    end)

    it("respects the limit for multibyte text", function()
      local result = text.truncate("\u{4f60}\u{597d}\u{4e16}\u{754c}\u{4f60}", 6)
      assert.equals("\u{4f60}...", result)
    end)

    it("never exceeds the limit, even when limit <= 3", function()
      -- regression: limit<=3 used to append a full "..." to leftover text,
      -- producing 3+ display columns for a 1-column budget
      for limit = 0, 3 do
        local result = text.truncate("xxxx", limit)
        assert.message(("limit=%d produced %q"):format(limit, result))
          .is_true(vim.fn.strdisplaywidth(result) <= limit)
      end
    end)

    it("returns the empty string for a non-positive limit", function()
      assert.equals("", text.truncate("anything", 0))
      assert.equals("", text.truncate("anything", -1))
    end)
  end)

  describe("utf8_safe_cut", function()
    it("returns short strings unchanged", function()
      assert.equals("abc", text.utf8_safe_cut("abc", 10))
    end)

    it("cuts ASCII exactly at the budget", function()
      assert.equals(string.rep("x", 10), text.utf8_safe_cut(string.rep("x", 20), 10))
    end)

    it("backs the cut off a multibyte character", function()
      -- 数 = 3 bytes: budget 10 would split the 4th char (bytes 10..12)
      local s = string.rep("\u{6570}", 5)
      local cut = text.utf8_safe_cut(s, 10)
      assert.equals(string.rep("\u{6570}", 3), cut)
    end)

    it("handles a cut landing exactly on a character boundary", function()
      local s = string.rep("\u{6570}", 3) -- 9 bytes
      assert.equals(string.rep("\u{6570}", 3), text.utf8_safe_cut(s, 9))
    end)
  end)
end)
