defmodule AntoniaApp.Logger.FormatterTest do
  use ExUnit.Case

  alias AntoniaApp.Logger.Formatter, as: LogFormatter

  describe "format/4" do
    setup do
      value = Application.get_env(:Antonia, LogFormatter)
      Application.put_env(:Antonia, LogFormatter, exclude: [:excluded_key])

      on_exit(fn ->
        Application.put_env(:Antonia, LogFormatter, value)
      end)
    end

    test "formats the level and the message provided in logfmt" do
      cases = [debug: "debugging", info: "informative", warning: "warnings!!", error: "error"]

      Enum.each(cases, fn {level, message} ->
        assert LogFormatter.format(level, message, {}, []) == "level=#{level} msg=#{message}\n"
      end)
    end

    test "formats all metadata provided " do
      assert "level=debug msg=message time=12345 custom_key=custom_data\n" ==
               LogFormatter.format("debug", "message", {},
                 time: 12_345,
                 custom_key: "custom_data"
               )
    end

    test "metadata excluded in the config is not present in the logfmt log" do
      assert "level=info msg=message\n" ==
               LogFormatter.format("info", "message", {}, excluded_key: :data)
    end
  end
end
