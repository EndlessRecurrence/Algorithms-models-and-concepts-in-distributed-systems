defmodule DistributedAlgorithmsApp.TimestampRankPair do
  defstruct timestamp: 0, writer_rank: 0, value: nil

  def new(timestamp, writer_rank, value) do
    %DistributedAlgorithmsApp.TimestampRankPair{
      timestamp: timestamp,
      writer_rank: writer_rank,
      value: value
    }
  end

end
