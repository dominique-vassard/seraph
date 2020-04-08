defmodule Seraph.Repo.Supervisor do
  use Supervisor

  def start_link(repo, otp_app, opts) do
    Supervisor.start_link(__MODULE__, {repo, otp_app, opts}, [])
  end

  def init({repo, otp_app, _opts}) do
    config =
      Application.get_env(otp_app, repo)
      |> Keyword.put_new(:prefix, repo)

    children = [
      {Bolt.Sips, config}
    ]

    opts = [strategy: :one_for_one, max_restarts: 0]

    Supervisor.init(children, opts)
  end
end
