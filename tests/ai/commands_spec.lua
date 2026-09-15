--- Tests for the session-delete command paths (commands.lua). The vim.ui
--- picker/input flows can't run headless, so the specs drive the confirmed
--- delete seam (_delete_confirmed) directly and pin its session/view effects.

describe("poste-ai.commands delete_session", function()
  local config = require("poste-ai.config")
  local session = require("poste-ai.chat.session")
  local commands = require("poste-ai.commands")

  local tmp_dir

  before_each(function()
    tmp_dir = vim.fn.tempname() .. "-sessions-delete"
    config.merge({ sessions_dir = tmp_dir })
    vim.fn.mkdir(tmp_dir, "p")
  end)

  after_each(function()
    vim.fn.delete(tmp_dir, "rf")
    config.config = vim.deepcopy(config.defaults)
    session.set_current(nil)
  end)

  it("deleting the current session clears it and tolerates the pointer", function()
    local s = session.new("doomed")
    s.messages = { { role = "user", text = "hi" } }
    session.save(s)

    commands._delete_confirmed(s.id)

    assert.is_nil(session.load(s.id))
    -- the pointer references the deleted file; the next current() must not
    -- resurrect it but fall back to a fresh session
    session.set_current(nil)
    local next_cur = session.current()
    assert.are_not.equal(s.id, next_cur.id)
  end)

  it("deleting another session leaves the current one intact", function()
    local other = session.new("other")
    session.save(other)
    local cur = session.new("kept")
    session.save(cur)

    commands._delete_confirmed(other.id)

    assert.is_nil(session.load(other.id))
    assert.are.equal(cur.id, session.current().id)
    assert.are.equal("kept", session.load(cur.id).name)
  end)
end)

describe("poste-ai.commands ask_selection", function()
  local commands = require("poste-ai.commands")
  local window = require("poste-ai.chat.window")

  after_each(function()
    window.close()
  end)

  it("prefills the input with a line-range mention of the selection", function()
    local path = vim.fn.tempname() .. "-selection.lua"
    vim.fn.writefile({ "line one", "line two", "line three" }, path)
    local buf = vim.fn.bufadd(path)
    vim.api.nvim_set_current_buf(buf)

    commands.ask_selection(nil, 2, 3)

    assert.is_true(window.is_open())
    local text = window.input_text()
    -- @<path>(2-3), pointing at the file that held the selection
    assert.truthy(text:match("^@.+%(2%-3%)$"))
    assert.truthy(text:find(vim.fn.fnamemodify(path, ":t"), 1, true))
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(path)
  end)

  it("appends to an existing draft instead of replacing it", function()
    local path = vim.fn.tempname() .. "-selection2.lua"
    vim.fn.writefile({ "a" }, path)
    local buf = vim.fn.bufadd(path)
    vim.api.nvim_set_current_buf(buf)
    window.open()
    window.set_input_text("what does this do")

    commands.ask_selection(nil, 1, 1)

    local text = window.input_text()
    assert.truthy(text:match("^what does this do @.+%(1%)$"))
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(path)
  end)

  it("warns on an unnamed buffer and leaves the chat closed", function()
    local scratch = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(scratch)

    commands.ask_selection(nil, 1, 2)

    assert.is_false(window.is_open())
    vim.api.nvim_buf_delete(scratch, { force = true })
  end)
end)
