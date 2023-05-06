defmodule DistributedAlgorithmsApp.TimestampRankPair do
  defstruct timestamp: 0, writer_rank: 0, value: %Proto.Value{defined: false, v: -1}

  def new(timestamp \\ 0, writer_rank \\ 0, value \\ %Proto.Value{defined: false, v: -1}) do
    %DistributedAlgorithmsApp.TimestampRankPair{
      timestamp: timestamp,
      writer_rank: writer_rank,
      value: value
    }
  end

  def compare(first_pair, second_pair) do
    cond do
      first_pair.timestamp > second_pair.timestamp -> true
      first_pair.timestamp == second_pair.timestamp and first_pair.writer_rank > second_pair.writer_rank -> true
      true -> false
    end
  end

end
