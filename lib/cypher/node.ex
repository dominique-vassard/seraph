defmodule Seraph.Cypher.Node do
  @doc """
  Builds a cypher query for listing all the constraints for a specific node.

  ## Example

      iex> Seraph.Cypher.Node.list_all_constraints("Post")
      "CALL db.constraints()
      YIELD description
      WHERE description CONTAINS \\":Post\\" \\nRETURN description
      "
      iex> Seraph.Cypher.Node.list_all_constraints("Post", :title)
      "CALL db.constraints()
      YIELD description
      WHERE description CONTAINS \\":Post\\" AND description CONTAINS '.title'
      RETURN description
      "
  """
  @spec list_all_constraints(String.t(), atom()) :: String.t()
  def list_all_constraints(node_label, property \\ nil) do
    where_prop =
      if property do
        "AND description CONTAINS '.#{property |> Atom.to_string()}'"
      end

    """
    CALL db.constraints()
    YIELD description
    WHERE description CONTAINS ":#{node_label}" #{where_prop}
    RETURN description
    """
  end

  @doc """
  Builds a cypher query for listing all the indexes for a specific node.

  ## Example

      iex> Seraph.Cypher.Node.list_all_indexes("Post")
      "CALL db.indexes()
      YIELD description
      WHERE description CONTAINS \\":Post\\" \\nRETURN description
      "
      iex> Seraph.Cypher.Node.list_all_indexes("Post", :title)
      "CALL db.indexes()
      YIELD description
      WHERE description CONTAINS \\":Post\\" AND description CONTAINS 'title'
      RETURN description
      "
  """
  @spec list_all_indexes(String.t(), nil | atom()) :: String.t()
  def list_all_indexes(node_label, property \\ nil) do
    where_prop =
      if property do
        "AND description CONTAINS '#{property |> Atom.to_string()}'"
      end

    """
    CALL db.indexes()
    YIELD description
    WHERE description CONTAINS ":#{node_label}" #{where_prop}
    RETURN description
    """
  end

  @doc """
  Builds a cypher for deleting a cosntraint or an index from the database.
  Required a constraint cql similar to the one provided by `CALL db.constraints()`

  ## Example

      iex> constraint_cql = "CONSTRAINT ON ( posts:posts ) ASSERT posts.uuid IS UNIQUE"
      iex> Seraph.Cypher.Node.drop_constraint_index_from_cql(constraint_cql)
      "DROP CONSTRAINT ON ( posts:posts ) ASSERT posts.uuid IS UNIQUE"
      iex> index_cql = "INDEX ON :posts(nodeId)"
      iex> Seraph.Cypher.Node.drop_constraint_index_from_cql(index_cql)
      "DROP INDEX ON :posts(nodeId)"
  """
  @spec drop_constraint_index_from_cql(String.t()) :: String.t()
  def drop_constraint_index_from_cql(cql) do
    "DROP " <> cql
  end
end
