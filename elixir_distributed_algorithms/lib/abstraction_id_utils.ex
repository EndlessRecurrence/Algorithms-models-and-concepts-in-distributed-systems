defmodule DistributedAlgorithmsApp.AbstractionIdUtils do

  def extract_topic_name(abstraction_string) do
    Regex.named_captures(~r/uc\[(?<topic_name>.*?)\]/, abstraction_string)
    |> Map.get("topic_name")
  end

  def extract_epoch_consensus_timestamp(abstraction_string) do
    Regex.named_captures(~r/ep\[(?<timestamp>.*?)\]/, abstraction_string)
    |> Map.get("timestamp")
  end

  def extract_register_name(abstraction_string) do
    Regex.named_captures(~r/nnar\[(?<register_name>.*?)\]/, abstraction_string)
    |> Map.get("register_name")
  end

end
