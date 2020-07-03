defmodule Seraph.Repo.Relationship.Queryable do
  @moduledoc false

  alias Seraph.Query.Builder

  @spec to_query(
          Seraph.Repo.queryable(),
          Seraph.Schema.Node.t() | map,
          Seraph.Schema.Node.t() | map,
          Keyword.t() | map,
          atom()
        ) :: Seraph.Query.t() | {:error, Keyword.t()}
  def to_query(queryable, start_struct_or_data, end_struct_or_data, rel_properties, :match) do
    rel_properties = Enum.into(rel_properties, %{})

    %{entity: relationship, params: query_params} =
      Builder.Entity.Relationship.from_queryable(
        queryable,
        start_struct_or_data,
        end_struct_or_data,
        rel_properties,
        "match__"
      )

    {_, func_atom, _, _} =
      Process.info(self(), :current_stacktrace)
      |> elem(1)
      |> Enum.at(2)

    literal =
      case func_atom do
        :get ->
          "get(#{inspect(start_struct_or_data)}, #{inspect(end_struct_or_data)})"

        :get_by ->
          "get_by(#{inspect(start_struct_or_data)}, #{inspect(end_struct_or_data)}, #{
            inspect(rel_properties)
          })"
      end

    %Seraph.Query{
      identifiers: Map.put(%{}, "rel", relationship),
      operations: [
        match: %Builder.Match{
          entities: [relationship]
        },
        return: %Builder.Return{
          raw_variables: [
            %Builder.Entity.EntityData{
              entity_identifier: :rel
            }
          ]
        }
      ],
      literal: [literal],
      params: query_params
    }
  end

  def to_query(queryable, start_struct_or_data, end_struct_or_data, rel_properties, :match_create) do
    rel_properties = Enum.into(rel_properties, %{})

    %{entity: relationship, params: query_params} =
      Builder.Entity.Relationship.from_queryable(
        queryable,
        start_struct_or_data,
        end_struct_or_data,
        rel_properties,
        "match_create__"
      )

    literal =
      "create(%#{queryable}{start: #{inspect(start_struct_or_data)}, end:#{
        inspect(end_struct_or_data)
      }, properties: #{inspect(rel_properties)}})"

    identifiers = %{
      "rel" => relationship,
      "start" => relationship.start,
      "end" => relationship.end
    }

    rel_to_create =
      relationship
      |> Map.put(:start, %Builder.Entity.Node{
        identifier: relationship.start.identifier,
        queryable: Seraph.Node
      })
      |> Map.put(:end, %Builder.Entity.Node{
        identifier: relationship.end.identifier,
        queryable: Seraph.Node
      })

    %Seraph.Query{
      identifiers: identifiers,
      operations: [
        match: %Builder.Match{
          entities: [relationship.start, relationship.end]
        },
        create: %Builder.Create{
          raw_entities: [rel_to_create]
        },
        return: %Builder.Return{
          raw_variables: [
            %Builder.Entity.EntityData{
              entity_identifier: :rel
            },
            %Builder.Entity.EntityData{
              entity_identifier: :start
            },
            %Builder.Entity.EntityData{
              entity_identifier: :end
            }
          ]
        }
      ],
      literal: [literal],
      params: query_params
    }
  end

  def to_query(queryable, start_struct_or_data, end_struct_or_data, rel_properties, :create) do
    rel_properties = Enum.into(rel_properties, %{})

    %{entity: relationship, params: query_params} =
      Builder.Entity.Relationship.from_queryable(
        queryable,
        start_struct_or_data,
        end_struct_or_data,
        rel_properties,
        "rel",
        "match_create__"
      )

    literal =
      "create(%#{queryable}{start: #{inspect(start_struct_or_data)}, end:#{
        inspect(end_struct_or_data)
      }, properties: #{inspect(rel_properties)}})"

    identifiers = %{
      "rel" => relationship,
      "start" => relationship.start,
      "end" => relationship.end
    }

    %Seraph.Query{
      identifiers: identifiers,
      operations: [
        create: %Builder.Create{
          raw_entities: [relationship]
        },
        return: %Builder.Return{
          raw_variables: [
            %Builder.Entity.EntityData{
              entity_identifier: :rel
            },
            %Builder.Entity.EntityData{
              entity_identifier: :start
            },
            %Builder.Entity.EntityData{
              entity_identifier: :end
            }
          ]
        }
      ],
      literal: [literal],
      params: query_params
    }
  end

  def to_query(queryable, start_data, end_data, merge_opts, :merge) do
    with {:ok, on_create_set_data} <-
           merge_set_operations(queryable, :on_create, Keyword.get(merge_opts, :on_create)),
         {:ok, on_match_set_data} <-
           merge_set_operations(queryable, :on_match, Keyword.get(merge_opts, :on_match)) do
      build_merge_query(
        queryable,
        start_data,
        end_data,
        on_create_set_data,
        on_match_set_data,
        merge_opts
      )
    else
      {:error, _} = error ->
        error
    end
  end

  def to_query(queryable, %Seraph.Changeset{} = changeset, :set) do
    anchors_changed? =
      :start_node in Map.keys(changeset.changes) or :end_node in Map.keys(changeset.changes)

    build_set_query(queryable, changeset, anchors_changed?)
  end

  def to_query(queryable, rel_data, :merge) do
    persisted_properties = queryable.__schema__(:persisted_properties)

    rel_properties =
      rel_data
      |> Map.from_struct()
      |> Enum.filter(fn {prop_name, prop_value} ->
        prop_name in persisted_properties and not is_nil(prop_value)
      end)
      |> Enum.into(%{})

    %{entity: relationship, params: params} =
      Builder.Entity.Relationship.from_queryable(
        queryable,
        rel_data.start_node,
        rel_data.end_node,
        rel_properties,
        "rel",
        "merge__"
      )

    rel_to_merge =
      relationship
      |> Map.put(:start, %Builder.Entity.Node{
        identifier: relationship.start.identifier,
        queryable: Seraph.Node
      })
      |> Map.put(:end, %Builder.Entity.Node{
        identifier: relationship.end.identifier,
        queryable: Seraph.Node
      })

    %Seraph.Query{
      identifiers: %{
        "start" => relationship.start,
        "end" => relationship.end,
        "rel" => relationship
      },
      operations: [
        match: %Builder.Match{entities: [relationship.start, relationship.end]},
        merge: %Builder.Merge{raw_entities: rel_to_merge},
        return: %Builder.Return{
          raw_variables: [
            %Builder.Entity.EntityData{
              entity_identifier: :rel
            },
            %Builder.Entity.EntityData{
              entity_identifier: :start
            },
            %Builder.Entity.EntityData{
              entity_identifier: :end
            }
          ]
        }
      ],
      literal: ["merge(#{inspect(rel_data)})"],
      params: params
    }
  end

  def to_query(queryable, rel_data, :delete) do
    %{entity: relationship, params: params} =
      Builder.Entity.Relationship.from_queryable(
        queryable,
        rel_data.start_node,
        rel_data.end_node,
        %{},
        "rel",
        "delete__"
      )

    %Seraph.Query{
      identifiers: %{
        "rel" => relationship,
        "start" => relationship.start,
        "end" => relationship.end
      },
      operations: [
        match: %Builder.Match{entities: [relationship]},
        delete: %Builder.Delete{
          raw_entities: [
            %Builder.Entity.EntityData{
              entity_identifier: "rel"
            }
          ]
        }
      ],
      literal: ["delete(#{inspect(rel_data)})"],
      params: params
    }
  end

  @doc """
  Fetch a single struct from the Neo4j datababase with the given start and end node data/struct.

  Returns `nil` if no result was found
  """
  @spec get(
          Seraph.Repo.t(),
          Seraph.Repo.queryable(),
          Seraph.Schema.Node.t() | map,
          Seraph.Schema.Node.t() | map
        ) :: nil | Seraph.Schema.Relationship.t()
  def get(repo, queryable, start_struct_or_data, end_struct_or_data) do
    results =
      to_query(queryable, start_struct_or_data, end_struct_or_data, %{}, :match)
      |> repo.all(relationship_result: :full)

    case length(results) do
      0 ->
        nil

      1 ->
        List.first(results)["rel"]

      count ->
        raise Seraph.MultipleRelationshipsError,
          queryable: queryable,
          count: count,
          start_node: queryable.__schema__(:start_node),
          end_node: queryable.__schema__(:end_node),
          params: %{
            start: start_struct_or_data,
            end: end_struct_or_data
          }
    end
  end

  @doc """
  Same as `get/4` but raises when no result is found.
  """
  @spec get!(
          Seraph.Repo.t(),
          Seraph.Repo.queryable(),
          Seraph.Schema.Node.t() | map,
          Seraph.Schema.Node.t() | map
        ) :: Seraph.Schema.Relationship.t()
  def get!(repo, queryable, start_struct_or_data, end_struct_or_data) do
    case get(repo, queryable, start_struct_or_data, end_struct_or_data) do
      nil ->
        params = %{
          start: start_struct_or_data,
          end: end_struct_or_data
        }

        raise Seraph.NoResultsError, queryable: queryable, function: :get!, params: params

      result ->
        result
    end
  end

  @doc """
  Fetch a single struct from the Neo4j datababase with the given data.

  Returns `nil` if no result was found
  """
  @spec get_by(
          Seraph.Repo.t(),
          Seraph.Repo.queryable(),
          Keyword.t() | map,
          Keyword.t() | map,
          Keyword.t() | map
        ) :: nil | Seraph.Schema.Relationship.t()
  def get_by(repo, queryable, start_node_clauses, end_node_clauses, relationship_clauses) do
    results =
      to_query(queryable, start_node_clauses, end_node_clauses, relationship_clauses, :match)
      |> repo.all(relationship_result: :full)

    case length(results) do
      0 ->
        nil

      1 ->
        List.first(results)["rel"]

      count ->
        raise Seraph.MultipleRelationshipsError,
          queryable: queryable,
          count: count,
          start_node: queryable.__schema__(:start_node),
          end_node: queryable.__schema__(:end_node),
          params: %{
            start: start_node_clauses,
            end: end_node_clauses
          }
    end
  end

  @doc """
  Same as `get/5` but raise when no result is found.
  """
  @spec get_by!(
          Seraph.Repo.t(),
          Seraph.Repo.queryable(),
          Keyword.t() | map,
          Keyword.t() | map,
          Keyword.t() | map
        ) ::
          Seraph.Schema.Relationship.t()
  def get_by!(repo, queryable, start_node_clauses, end_node_clauses, relationship_clauses) do
    case get_by(repo, queryable, start_node_clauses, end_node_clauses, relationship_clauses) do
      nil ->
        raise Seraph.NoResultsError,
          queryable: queryable,
          function: :get!,
          params: %{
            start_node: start_node_clauses,
            end_node: end_node_clauses,
            relationship: relationship_clauses
          }

      result ->
        result
    end
  end

  defp build_set_query(queryable, changeset, false) do
    persisted_properties = queryable.__schema__(:persisted_properties)

    rel_properties =
      changeset.changes
      |> Enum.filter(fn {prop_name, _} ->
        prop_name in persisted_properties
      end)

    %{entity: relationship, params: query_params} =
      Builder.Entity.Relationship.from_queryable(
        queryable,
        changeset.data.start_node,
        changeset.data.end_node,
        %{},
        "rel",
        "match_set__"
      )

    {to_remove, to_set} = Enum.split_with(rel_properties, fn {_, value} -> is_nil(value) end)

    %{set: set, params: set_params} = Builder.Set.build_from_map(Enum.into(to_set, %{}), "rel")
    remove = Builder.Remove.build_from_map(Enum.into(to_remove, %{}), "rel")

    %Seraph.Query{
      identifiers: %{
        "rel" => relationship,
        "start" => relationship.start,
        "end" => relationship.end
      },
      operations: [
        match: %Builder.Match{entities: [relationship]},
        set: set,
        remove: remove,
        return: %Builder.Return{
          raw_variables: [
            %Builder.Entity.EntityData{
              entity_identifier: :rel
            },
            %Builder.Entity.EntityData{
              entity_identifier: :start
            },
            %Builder.Entity.EntityData{
              entity_identifier: :end
            }
          ]
        }
      ],
      literal: "set(#{inspect(changeset)})",
      params: query_params ++ set_params
    }
  end

  defp build_set_query(queryable, changeset, true) do
    %{entity: rel_to_match, params: match_params} =
      Builder.Entity.Relationship.from_queryable(
        queryable,
        changeset.data.start_node,
        changeset.data.end_node,
        %{},
        "old_rel",
        "match_create__"
      )

    match_entities = [rel_to_match.start, rel_to_match.end, rel_to_match]

    match_identifiers = %{
      "start" => rel_to_match.start,
      "old_rel" => rel_to_match,
      "end" => rel_to_match.end
    }

    match_return_variables = %{
      start: %Builder.Entity.EntityData{
        entity_identifier: :start
      },
      end: %Builder.Entity.EntityData{
        entity_identifier: :end
      }
    }

    final_rel = Seraph.Changeset.apply_changes(changeset)

    persisted_properties = queryable.__schema__(:persisted_properties)

    %{entity: new_start_node, params: new_start_params} =
      if final_rel.start_node == changeset.data.start_node do
        %{entity: rel_to_match.start, params: []}
      else
        start_queryable = queryable.__schema__(:start_node)

        start_properties = Seraph.Repo.Helper.extract_node_properties(final_rel.start_node)

        Builder.Entity.Node.from_queryable(
          start_queryable,
          start_properties,
          "match_create__",
          "new_start"
        )
      end

    %{entity: new_end_node, params: new_end_params} =
      if final_rel.end_node == changeset.data.end_node do
        %{entity: rel_to_match.end, params: []}
      else
        end_queryable = queryable.__schema__(:end_node)

        end_properties = Seraph.Repo.Helper.extract_node_properties(final_rel.end_node)

        Builder.Entity.Node.from_queryable(
          end_queryable,
          end_properties,
          "match_create__",
          "new_end"
        )
      end

    create_return_variables =
      %{}
      |> Map.put(String.to_atom(new_start_node.identifier), %Builder.Entity.EntityData{
        entity_identifier: String.to_atom(new_start_node.identifier)
      })
      |> Map.put(String.to_atom(new_end_node.identifier), %Builder.Entity.EntityData{
        entity_identifier: String.to_atom(new_end_node.identifier)
      })

    pre_rel_to_create =
      %Builder.Entity.Relationship{
        queryable: queryable,
        identifier: "rel",
        type: queryable.__schema__(:type)
      }
      |> Map.put(:start, new_start_node)
      |> Map.put(:end, new_end_node)

    rel_properties =
      changeset
      |> Seraph.Changeset.apply_changes()
      |> Map.from_struct()
      |> Enum.filter(fn {prop_name, _} ->
        prop_name in persisted_properties
      end)

    props =
      rel_properties
      |> Enum.into(%{})
      |> Builder.Entity.Property.from_map(pre_rel_to_create)

    %{entity: rel_to_create, params: full_rel_params} =
      Builder.Entity.extract_params(
        Map.put(pre_rel_to_create, :properties, props),
        [],
        "match_create__"
      )

    rel_params =
      full_rel_params
      |> Enum.filter(fn {key, _} ->
        key |> Atom.to_string() |> String.starts_with?("rel")
      end)

    new_rel =
      rel_to_create
      |> Map.put(:start, %Builder.Entity.Node{
        identifier: rel_to_create.start.identifier,
        queryable: Seraph.Node
      })
      |> Map.put(:end, %Builder.Entity.Node{
        identifier: rel_to_create.end.identifier,
        queryable: Seraph.Node
      })

    create_match_entities = [rel_to_create.start, rel_to_create.end]

    create_identifiers =
      %{"rel" => rel_to_create}
      |> Map.put(rel_to_create.start.identifier, rel_to_create.start)
      |> Map.put(rel_to_create.end.identifier, rel_to_create.end)

    return_variables =
      match_return_variables
      |> Map.merge(create_return_variables)
      |> Map.values()

    literal = "set(#{inspect(changeset)})"

    %Seraph.Query{
      identifiers: Map.merge(match_identifiers, create_identifiers),
      operations: [
        match: %Builder.Match{
          entities: MapSet.new(match_entities ++ create_match_entities) |> MapSet.to_list()
        },
        delete: %Builder.Delete{
          raw_entities: [%Builder.Entity.EntityData{entity_identifier: "old_rel"}]
        },
        create: %Builder.Create{raw_entities: [new_rel]},
        return: %Builder.Return{
          raw_variables: [
            %Builder.Entity.EntityData{
              entity_identifier: :rel
            }
            | return_variables
          ]
        }
      ],
      literal: literal,
      params:
        match_params
        |> Keyword.merge(new_start_params)
        |> Keyword.merge(new_end_params)
        |> Keyword.merge(rel_params)
    }
  end

  defp build_merge_query(
         queryable,
         start_node,
         end_node,
         on_create_set_data,
         on_match_set_data,
         merge_opts
       ) do
    %{entity: relationship, params: rel_params} =
      Builder.Entity.Relationship.from_queryable(
        queryable,
        start_node,
        end_node,
        %{},
        "rel",
        "merge__"
      )

    rel_to_merge =
      relationship
      |> Map.put(:start, %Builder.Entity.Node{
        identifier: relationship.start.identifier,
        queryable: Seraph.Node
      })
      |> Map.put(:end, %Builder.Entity.Node{
        identifier: relationship.end.identifier,
        queryable: Seraph.Node
      })

    literal =
      "merge(#{queryable}, #{inspect(start_node)}, #{inspect(end_node)}, #{inspect(merge_opts)})"

    %Seraph.Query{
      identifiers: %{
        "rel" => relationship,
        "start" => relationship.start,
        "end" => relationship.end
      },
      operations: [
        match: %Builder.Match{entities: [relationship.start, relationship.end]},
        merge: %Builder.Merge{raw_entities: rel_to_merge},
        on_create_set: %Builder.OnCreateSet{expressions: on_create_set_data.set.expressions},
        on_match_set: %Builder.OnMatchSet{expressions: on_match_set_data.set.expressions},
        return: %Builder.Return{
          raw_variables: [
            %Builder.Entity.EntityData{
              entity_identifier: :rel
            },
            %Builder.Entity.EntityData{
              entity_identifier: :start
            },
            %Builder.Entity.EntityData{
              entity_identifier: :end
            }
          ]
        }
      ],
      literal: [literal],
      params: rel_params ++ on_create_set_data.params ++ on_match_set_data.params
    }
  end

  @spec merge_set_operations(Seraph.Repo.queryable(), :on_create | :on_match, tuple) ::
          {:ok, map} | {:error, Keyword.t()}
  defp merge_set_operations(queryable, operation, {data, changeset_fn}) do
    case changeset_fn.(struct!(queryable, %{}), data) do
      %Seraph.Changeset{valid?: true} = changeset ->
        persisted_properties = queryable.__schema__(:persisted_properties)

        rel_properties =
          changeset.changes
          |> Enum.filter(fn {prop_name, _} ->
            prop_name in persisted_properties
          end)

        set_data = Builder.Set.build_from_map(Enum.into(rel_properties, %{}), "rel")
        {:ok, set_data}

      changeset ->
        {:error, [{operation, changeset}]}
    end
  end

  defp merge_set_operations(_, _, nil) do
    {:ok, %{set: %Builder.OnCreateSet{expressions: []}, params: []}}
  end
end
