defmodule DistributedAlgorithmsApp.TimestampRankPair do
  defstruct timestamp: 0, writer_rank: 0, value: %Proto.Value{defined: false, v: -1}

  def new(timestamp \\ 0, writer_rank \\ 0, value \\ %Proto.Value{defined: false, v: -1}) do
    %DistributedAlgorithmsApp.TimestampRankPair{
      timestamp: timestamp,
      writer_rank: writer_rank,
      value: value
    }
  end

end
