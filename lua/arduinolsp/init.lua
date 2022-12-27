local settings = require 'arduinolsp.settings'
local utility = require 'arduinolsp.utility'
local path = require 'arduinolsp.path'
local details = require 'arduinolsp.details'

local M = {}

---Setup function
---@param config table
function M.setup(config)
  settings.sketchdir = false

  if not config then return end

  settings.set(config)
  local conf = settings.current

  if not details.is_exe(conf.clangd) then
    details.error(('%s is not and executable'):format(conf.clangd))
    return
  end

  if utility.is_empty(conf.arduino_config_dir) then
    details.error('arduino_config_dir is empty')
    return
  end

  if not details.is_dir(conf.config_dir) then
    vim.fn.mkdir(conf.config_dir, '')
  end
end

---Called by lspconfig, configures language server
---@param config table
---@param root_dir string
function M.on_new_config(config, root_dir)
  local m_settings = settings.current
  local fqbn = details.get_fqbn(root_dir)

  local config_dir = path.concat {
    m_settings.arduino_config_dir, 'arduino-cli.yaml'
  }

  settings.config_dir = config_dir
  settings.sketchdir = true

  config.cmd = {
    'arduino-language-server',
    '-cli-config', config_dir,
    '-clangd', m_settings.clangd,
    '-cli', settings.current.arduino,
    '-fqbn', fqbn
  }

  details.warn(details.serialize(config.cmd))
end

---Prints current config
function M.dump_config()
  if not settings.sketchdir then
    print(('%s Current directory is not a sketch directory')
      :format(details.plugname))
    return
  end

  print(('%s Config Dump\n'):format(details.plugname))

  local fqbn_table = details.get_data_from_config()

  local dir = vim.fn.getcwd()
  local fqbn = fqbn_table[dir]

  print(('Arduino config directory: %q'):format(settings.config_dir))
  print(('Clangd: %q'):format(settings.current.clangd))
  print(('Arduino: %q'):format(settings.current.arduino))
  print(('Current FQBN: %q'):format(fqbn))
end

function M.set_fqbn(fqbn)
  if not settings.sketchdir then
    details.warn('Current directory is not a sketch directory')
    return
  end

  local data = details.get_data_from_config()
  local dir = vim.fn.getcwd()
  data[dir] = fqbn
  utility.write_file(details.config_file, utility.serialize(data))
end

function M.clean_config()
  local fqbn_table = details.get_data_from_config()

  print(('%s Clean Config'):format(details.plugname))

  local counter = 0
  for dirname, _ in pairs(fqbn_table) do
    if not details.is_dir(dirname) then
      fqbn_table[dirname] = nil
      counter = counter + 1
    end
  end

  print('Done! Removed ' .. counter
    .. ' nonexistent directories from config')
end

---Calls arduino program, parses its data path and returns.
---Unnecessary argument - path to the program (by default function finds
---path to 'arduino-cli'). If passed, it will be stored in settings and
---called to determine the data path.
---@nodiscard
---@param arduino? string
---@return string|nil
function M.get_arduinocli_datapath(arduino)
  if type(arduino) == "string" then
    if not details.is_exe(arduino) then
      details.error(("%q is not an executable"):format(arduino))
      return nil
    end

    settings.current.arduino = arduino
  else
    arduino = settings.current.arduino
  end

  local output = vim.fn.system({
    arduino, 'config', 'dump'
  })

  if not output then
    details.error(('no output from %q'):format(arduino))
    return nil
  end

  local regex = vim.regex(details.data_regexp_pattern)
  local str_beg, str_end = regex:match_str(output)

  if not str_beg then
    details.error(('unexpected data from %q, regex error')
      :format(arduino))
    return nil
  end

  local datapath = string.sub(output, str_beg, str_end)

  return datapath
end

return M
