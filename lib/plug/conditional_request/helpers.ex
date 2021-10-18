defmodule Plug.ConditionalRequest.Helpers do
  alias Plug.Conn

  import Plug.Conn

  @spec when_stale(Conn.t(), Enum.t(), function()) :: Conn.t()
  def when_stale(conn, data, fun) when is_function(fun, 1) do
    validators = conn.private[:validators]
    generate_etag = Keyword.get(validators, :etag, fn _ -> nil end)
    last_modified = Keyword.get(validators, :last_modified, fn _ -> nil end)
    data = Enum.into(data, %{})
    etag = generate_etag.(data)
    modified = last_modified.(data)

    conn =
      conn
      |> put_etag(etag)
      |> put_last_modified(modified)

    if stale?(conn, etag, modified) do
      fun.(conn)
    else
      send_resp(conn, 304, "")
    end
  end

  def stale?(_, nil, nil), do: true

  def stale?(conn, etag, last_modified) do
    none_match =
      conn
      |> get_req_header("if-none-match")
      |> List.first()

    modified_since =
      conn
      |> get_req_header("if-modified_since")
      |> List.first()

    none_match?(none_match, etag) or modified_since?(modified_since, last_modified)
  end

  defp none_match?(nil, _), do: false
  defp none_match?(_, nil), do: false

  defp none_match?(none_match, {_type, etag}) do
    none_match = Plug.Conn.Utils.list(none_match)

    etag not in none_match
  end

  defp modified_since?(nil, _), do: false
  defp modified_since?(_, nil), do: false

  defp modified_since?(modified_since, last_modified) do
    modified_since = parse_to_unix(modified_since)
    last_modified = date_to_unix(last_modified)

    last_modified > modified_since
  end

  def put_etag(conn, nil), do: conn
  def put_etag(conn, {:weak, etag}), do: put_resp_header(conn, "etag", "W/\"#{etag}\"")
  def put_etag(conn, {:strong, etag}), do: put_resp_header(conn, "etag", etag)

  def put_last_modified(conn, nil), do: conn

  def put_last_modified(conn, last_modified),
    do: put_resp_header(conn, "last-modified", date_to_http_date(last_modified))

  def etag_from_schema(schema) do
    schema
    |> List.wrap()
    |> Enum.map(fn schema ->
      [schema.__struct__, schema.id, NaiveDateTime.to_erl(schema.updated_at)]
    end)
    |> :erlang.term_to_binary()
    |> then(fn bin ->
      hash = Base.encode16(:crypto.hash(:md5, bin), case: :lower)

      {:weak, hash}
    end)
  end

  def last_modified_from_schema(schema) do
    schema
    |> List.wrap()
    |> Enum.map(& &1.updated_at)
    |> Enum.sort_by(&NaiveDateTime.to_erl/1)
    |> List.first()
  end

  defp date_to_http_date(date), do: date |> NaiveDateTime.to_erl() |> :cow_date.rfc1123()

  defp date_to_unix(%DateTime{} = date), do: DateTime.to_unix(date)
  defp date_to_unix(naive), do: naive |> DateTime.from_naive!("Etc/UTC") |> date_to_unix()

  defp parse_to_unix(date) do
    date
    |> :cow_date.parse_date()
    |> NaiveDateTime.from_erl!()
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix()
  end
end
