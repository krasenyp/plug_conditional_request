defmodule Plug.ConditionalRequest do
  @behaviour Plug

  import Plug.Conn

  @schema [
    validators: [
      type: :non_empty_keyword_list,
      required: true,
      doc: "Contains validator for ETag, last modified date or both.",
      keys: [
        etag: [
          type: {:fun, 1},
          doc: "A unary function which takes data and returns an ETag."
        ],
        last_modified: [
          type: {:fun, 1},
          doc: "A unary function which takes data and returns it's last modified date."
        ]
      ]
    ]
  ]

  def init(opts) do
    NimbleOptions.validate!(opts, @schema)
  end

  def call(conn, opts) do
    put_private(conn, :validators, opts[:validators])
  end
end
