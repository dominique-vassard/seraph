defmodule Seraph.MixProject do
  use Mix.Project

  @version "0.1.1"

  def project do
    [
      name: "Seraph",
      app: :seraph,
      version: @version,
      elixir: "~> 1.8",
      package: package(),
      description: "A toolkit for data mapping an querying Neo4j database in Elixir",
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

  defp package() do
    %{
      licenses: ["Apache-2.0"],
      maintainers: ["Dominique VASSARD"],
      links: %{"Github" => "https://github.com/dominique-vassard/seraph"}
    }
  end

  defp docs do
    [
      assets: "assets",
      source_ref: "v#{@version}",
      main: "readme",
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: groups_for_modules()
    ]
  end

  defp extras do
    [
      "README.md",
      "guide/up_and_running.md",
      "guide/schema.md",
      "guide/creating.md",
      "guide/getting.md",
      "guide/setting.md",
      "guide/merging.md",
      "guide/deleting.md"
    ]
  end

  defp groups_for_extras do
    [
      Guide: ~r/guide\/[^\/]+\.md/
    ]
  end

  defp groups_for_modules do
    [
      "Example Repo": [
        Seraph.Example.Repo,
        Seraph.Example.Repo.Node,
        Seraph.Example.Repo.Relationship
      ],
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
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bolt_sips, "~> 2.0"},
      {:ecto, "~>3.2"},
      {:uuid, "~> 1.1"},
      {:inflex, "~> 2.0.0"},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false}
    ]
  end
end
