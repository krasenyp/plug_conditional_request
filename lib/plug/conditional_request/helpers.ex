defmodule Plug.ConditionalRequest.Helpers do
  alias Plug.Conn

  import Plug.Conn

  require Logger

  defguardp is_query(method) when method in ["GET", "HEAD"]
  defguardp is_mutation(method) when method in ["POST", "PUT", "PATCH", "DELETE"]

  @spec when_stale(Conn.t(), Enum.t(), function()) :: Conn.t()
  def when_stale(%Conn{method: method} = conn, data, fun)
      when is_query(method) and is_function(fun, 1) do
    {etag, modified} = get_validators(conn, data)

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

  def when_stale(conn, _data, _fun) do
    Logger.warn("Function \"when_stale\" is a no-op on methods other than GET and HEAD.")

    conn
  end

  @spec when_fresh(Conn.t(), Enum.t(), function()) :: Conn.t()
  def when_fresh(%Conn{method: method} = conn, data, fun)
      when is_mutation(method) and is_function(fun, 0) do
    {etag, modified} = get_validators(conn, data)

    if stale?(conn, etag, modified) do
      send_resp(conn, 409, "")
    else
      fun.()
    end
  end

  def when_fresh(conn, _data, _fun) do
    Logger.warn(
      "Function \"when_fresh\" is a no-op on methods other than PUT, POST, PATCH and DELETE."
    )

    conn
  end

  defp get_validators(conn, data) do
    validators = conn.private[:validators]
    generate_etag = Keyword.get(validators, :etag, fn _ -> nil end)
    last_modified = Keyword.get(validators, :last_modified, fn _ -> nil end)
    data = Enum.into(data, %{})
    etag = generate_etag.(data)
    modified = last_modified.(data)

    {etag, modified}
  end

  def stale?(_, nil, nil), do: true

  def stale?(conn, etag, last_modified) do
    none_match = get_fingerprint_header(conn)
    modified_since = get_timestamp_header(conn)

    not fingerprint_match?(none_match, etag) or modified_since?(modified_since, last_modified)
  end

  defp get_fingerprint_header(%{method: method} = conn) when is_query(method) do
    conn
    |> get_req_header("if-none-match")
    |> List.first()
  end

  defp get_fingerprint_header(%{method: method} = conn) when is_mutation(method) do
    conn
    |> get_req_header("if-match")
    |> List.first()
  end

  defp get_timestamp_header(%{method: method} = conn) when is_query(method) do
    conn
    |> get_req_header("if-modified_since")
    |> List.first()
  end

  defp get_timestamp_header(%{method: method} = conn) when is_mutation(method) do
    conn
    |> get_req_header("if-not-modified_since")
    |> List.first()
  end

  defp fingerprint_match?(nil, _), do: false
  defp fingerprint_match?(_, nil), do: false

  defp fingerprint_match?(fingerprint, {_type, etag}) do
    fingerprint = Plug.Conn.Utils.list(fingerprint)

    etag in fingerprint
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
