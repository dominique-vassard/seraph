defmodule Seraph.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :seraph,
      version: @version,
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      docs: docs(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Seraph.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "examples"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      source_ref: "v#{@version}",
      groups_for_modules: [
        Schema: [
          Seraph.Schema.Node,
          Seraph.Schema.Node.Metadata,
          Seraph.Schema.Relationship,
          Seraph.Schema.Relationship.Metadata
        ],
        "(Not) Loaded struct info": [
          Seraph.Schema.Node.NotLoaded,
          Seraph.Schema.Relationship.NotLoaded,
          Seraph.Schema.Relationship.Outgoing,
          Seraph.Schema.Relationship.Incoming
        ]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bolt_sips, "~> 2.0"},
      {:ecto, "~>3.2"},
      {:uuid, "~> 1.1"},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
