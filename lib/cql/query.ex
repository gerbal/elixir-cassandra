defmodule CQL.Query do
  @moduledoc """
  Represents a CQL query statement
  """

  import CQL.DataTypes.Encoder

  alias CQL.{Request, QueryParams}

  defstruct query: "",
            params: %QueryParams{}

  defimpl Request do
    def encode(%CQL.Query{query: query, params: %QueryParams{} = params}) do
      with {:ok, encoded_query} <- ok(long_string(query)),
           {:ok, encoded_params} <- ok(QueryParams.encode(params)) do
        {:QUERY, encoded_query <> encoded_params}
      end
    end

    def encode(_), do: CQL.Error.new("invalid query request")
  end
end
