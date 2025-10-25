defmodule MermaidLiveSsr.MixProject do
  use Mix.Project

  def project do
    [
      app: :mermaidlive_ssr,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [:error_handling, :underspecs],
        # Only check project modules, not dependencies
        plt_add_apps: [:mix],
        # Ignore specific warnings
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      docs: [
        main: "MermaidLiveSsr",
        extras: ["README.md"],
        source_url: "https://github.com/dmitryledentsov/mermaidlive-ssr",
        source_ref: "main"
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {MermaidLiveSsr.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.21"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, ">= 0.37.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:req, "~> 0.5.10"},
      {:delta_crdt, "~> 0.6.5"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:gen_server_virtual_time, path: "../../gen_server_virtual_time"},
      # {:gen_server_virtual_time, "~> 0.5.0-rc.3"},
      # Quality assurance dependencies
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:junit_formatter, "~> 3.3", only: :test},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind mermaidlive_ssr", "esbuild mermaidlive_ssr"],
      "assets.deploy": [
        "tailwind mermaidlive_ssr --minify",
        "esbuild mermaidlive_ssr --minify",
        "phx.digest"
      ],
      # Quality assurance aliases
      quality: ["format --check-formatted", "credo --strict", "dialyzer"],
      "quality.fix": ["format", "credo --strict"],
      test: ["test --formatter JUnitFormatter --formatter ExUnit.CLIFormatter"],
      "test.coverage": ["coveralls", "coveralls.html"]
    ]
  end
end
