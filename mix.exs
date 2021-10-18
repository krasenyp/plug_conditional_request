defmodule Plug.ConditionalRequest.MixProject do
  use Mix.Project

  def project do
    [
      app: :plug_conditional_request,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, "~> 2.5"},
      {:ex_doc, "~> 0.25", only: :dev, runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:nimble_options, "~> 0.3.7"}
    ]
  end
end
