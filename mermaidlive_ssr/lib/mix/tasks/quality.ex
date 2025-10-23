defmodule Mix.Tasks.Quality do
  @moduledoc """
  Runs all code quality checks locally.

  This task runs the same quality checks that CI runs, helping you catch issues before pushing to GitHub.

  ## Usage

      mix quality          # Run all quality checks
      mix quality --fix    # Run quality checks and fix what can be auto-fixed

  ## What it checks

  - **Code formatting** with `mix format --check-formatted`
  - **Code analysis** with Credo (static analysis)
  - **Type checking** with Dialyzer
  - **Test coverage** with ExCoveralls

  ## Examples

      # Run all quality checks
      mix quality

      # Fix formatting issues automatically
      mix quality --fix

      # Run only specific checks
      mix format --check-formatted
      mix credo --strict
      mix dialyzer
      mix test.coverage

  ## CI Integration

  This task runs the same checks as the GitHub Actions CI pipeline.
  Run this before pushing to ensure your code passes all quality gates.
  """

  use Mix.Task
  require Logger

  @switches [
    fix: :boolean,
    help: :boolean
  ]

  @aliases [
    f: :fix,
    h: :help
  ]

  @dialyzer {:nowarn_function, run: 1}
  def run(args) do
    {opts, _args, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    if opts[:help] do
      print_help()
      System.halt(0)
    end

    IO.puts("🔍 Running code quality checks...")
    IO.puts("")

    if opts[:fix] do
      IO.puts("🔧 Auto-fixing issues where possible...")
      IO.puts("")
    end

    checks = [
      {"Code Formatting", &check_formatting/1},
      {"Static Analysis (Credo)", &check_credo/1},
      {"Type Checking (Dialyzer)", &check_dialyzer/1},
      {"Test Coverage", &check_coverage/1}
    ]

    results = Enum.map(checks, fn {name, check_fn} -> {name, check_fn.(opts)} end)

    IO.puts("")
    IO.puts("📊 Quality Check Results:")
    IO.puts("=" |> String.duplicate(50))

    failed_checks = Enum.filter(results, fn {_name, success} -> !success end)

    Enum.each(results, fn {name, success} ->
      status = if success, do: "✅ PASS", else: "❌ FAIL"
      IO.puts("#{status} #{name}")
    end)

    IO.puts("")

    if failed_checks == [] do
      IO.puts("🎉 All quality checks passed!")
      IO.puts("")
      IO.puts("Your code is ready for commit and push.")
      System.halt(0)
    else
      IO.puts("⚠️  Some quality checks failed.")
      IO.puts("")
      IO.puts("Run `mix quality --fix` to auto-fix formatting issues.")
      IO.puts("Fix other issues manually and run `mix quality` again.")
      System.halt(1)
    end
  end

  defp print_help do
    IO.puts(@moduledoc)
  end

  defp check_formatting(opts) do
    IO.puts("🔍 Checking code formatting...")

    command = if opts[:fix], do: "mix format", else: "mix format --check-formatted"

    case System.cmd("sh", ["-c", command], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✅ Code formatting is correct")
        true

      {output, _exit_code} ->
        IO.puts("❌ Code formatting issues found:")
        IO.puts(output)
        false
    end
  end

  defp check_credo(_opts) do
    IO.puts("🔍 Running Credo static analysis...")

    case System.cmd("mix", ["credo", "--strict"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✅ Credo analysis passed")
        true

      {output, _exit_code} ->
        IO.puts("❌ Credo found issues:")
        IO.puts(output)
        false
    end
  end

  defp check_dialyzer(_opts) do
    IO.puts("🔍 Running Dialyzer type checking...")

    case System.cmd("mix", ["dialyzer", "--format", "github"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✅ Dialyzer type checking passed")
        true

      {output, _exit_code} ->
        IO.puts("❌ Dialyzer found type issues:")
        IO.puts(output)
        false
    end
  end

  defp check_coverage(_opts) do
    IO.puts("🔍 Running test coverage analysis...")

    case System.cmd("mix", ["test.coverage"], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts("✅ Test coverage analysis completed")
        # Extract coverage percentage from output
        coverage_line =
          output
          |> String.split("\n")
          |> Enum.find(&String.contains?(&1, "TOTAL"))

        if coverage_line do
          IO.puts("📊 #{coverage_line}")
        end

        true

      {output, _exit_code} ->
        IO.puts("❌ Test coverage analysis failed:")
        IO.puts(output)
        false
    end
  end
end
