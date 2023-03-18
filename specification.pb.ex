defmodule Main.Message.Type do
  @moduledoc false
  use Protobuf, enum: true, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :NETWORK_MESSAGE, 0
  field :PROC_REGISTRATION, 1
  field :PROC_INITIALIZE_SYSTEM, 2
  field :PROC_DESTROY_SYSTEM, 3
  field :APP_BROADCAST, 4
  field :APP_VALUE, 5
  field :APP_DECIDE, 6
  field :APP_PROPOSE, 7
  field :APP_READ, 8
  field :APP_WRITE, 9
  field :APP_READ_RETURN, 10
  field :APP_WRITE_RETURN, 11
  field :UC_DECIDE, 20
  field :UC_PROPOSE, 21
  field :EP_ABORT, 30
  field :EP_ABORTED, 31
  field :EP_DECIDE, 32
  field :EP_INTERNAL_ACCEPT, 33
  field :EP_INTERNAL_DECIDED, 34
  field :EP_INTERNAL_READ, 35
  field :EP_INTERNAL_STATE, 36
  field :EP_INTERNAL_WRITE, 37
  field :EP_PROPOSE, 38
  field :EC_INTERNAL_NACK, 40
  field :EC_INTERNAL_NEW_EPOCH, 41
  field :EC_START_EPOCH, 42
  field :BEB_BROADCAST, 50
  field :BEB_DELIVER, 51
  field :ELD_TIMEOUT, 60
  field :ELD_TRUST, 61
  field :NNAR_INTERNAL_ACK, 70
  field :NNAR_INTERNAL_READ, 71
  field :NNAR_INTERNAL_VALUE, 72
  field :NNAR_INTERNAL_WRITE, 73
  field :NNAR_READ, 74
  field :NNAR_READ_RETURN, 75
  field :NNAR_WRITE, 76
  field :NNAR_WRITE_RETURN, 77
  field :EPFD_INTERNAL_HEARTBEAT_REPLY, 80
  field :EPFD_INTERNAL_HEARTBEAT_REQUEST, 81
  field :EPFD_RESTORE, 82
  field :EPFD_SUSPECT, 83
  field :EPFD_TIMEOUT, 84
  field :PL_DELIVER, 90
  field :PL_SEND, 91
end

defmodule Main.ProcessId do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :host, 1, type: :string
  field :port, 2, type: :int32
  field :owner, 3, type: :string
  field :index, 4, type: :int32
  field :rank, 5, type: :int32
end

defmodule Main.Value do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :defined, 1, type: :bool
  field :v, 2, type: :int32
end

defmodule Main.ProcRegistration do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :owner, 1, type: :string
  field :index, 2, type: :int32
end

defmodule Main.ProcInitializeSystem do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :processes, 1, repeated: true, type: Main.ProcessId
end

defmodule Main.ProcDestroySystem do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Main.AppBroadcast do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Main.Value
end

defmodule Main.AppValue do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Main.Value
end

defmodule Main.AppPropose do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :topic, 1, type: :string
  field :value, 2, type: Main.Value
end

defmodule Main.AppDecide do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Main.Value
end

defmodule Main.AppRead do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :register, 1, type: :string
end

defmodule Main.AppWrite do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :register, 1, type: :string
  field :value, 2, type: Main.Value
end

defmodule Main.AppReadReturn do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :register, 1, type: :string
  field :value, 2, type: Main.Value
end

defmodule Main.AppWriteReturn do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :register, 1, type: :string
end

defmodule Main.UcPropose do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Main.Value
end

defmodule Main.UcDecide do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Main.Value
end

defmodule Main.EpAbort do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Main.EpAborted do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :ets, 1, type: :int32
  field :valueTimestamp, 2, type: :int32
  field :value, 3, type: Main.Value
end

defmodule Main.EpPropose do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Main.Value
end

defmodule Main.EpDecide do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :ets, 1, type: :int32
  field :value, 2, type: Main.Value
end

defmodule Main.EpInternalRead do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Main.EpInternalState do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :valueTimestamp, 1, type: :int32
  field :value, 2, type: Main.Value
end

defmodule Main.EpInternalWrite do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Main.Value
end

defmodule Main.EpInternalAccept do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Main.EpInternalDecided do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Main.Value
end

defmodule Main.EcInternalNack do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Main.EcStartEpoch do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :newTimestamp, 1, type: :int32
  field :newLeader, 2, type: Main.ProcessId
end

defmodule Main.EcInternalNewEpoch do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :timestamp, 1, type: :int32
end

defmodule Main.BebBroadcast do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :message, 1, type: Main.Message
end

defmodule Main.BebDeliver do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :message, 1, type: Main.Message
  field :sender, 2, type: Main.ProcessId
end

defmodule Main.EldTimeout do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Main.EldTrust do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :process, 1, type: Main.ProcessId
end

defmodule Main.NnarRead do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Main.NnarInternalRead do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :readId, 1, type: :int32
end

defmodule Main.NnarInternalValue do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :readId, 1, type: :int32
  field :timestamp, 2, type: :int32
  field :writerRank, 3, type: :int32
  field :value, 4, type: Main.Value
end

defmodule Main.NnarInternalWrite do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :readId, 1, type: :int32
  field :timestamp, 2, type: :int32
  field :writerRank, 3, type: :int32
  field :value, 4, type: Main.Value
end

defmodule Main.NnarWrite do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Main.Value
end

defmodule Main.NnarInternalAck do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :readId, 1, type: :int32
end

defmodule Main.NnarReadReturn do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: Main.Value
end

defmodule Main.NnarWriteReturn do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Main.EpfdTimeout do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Main.EpfdInternalHeartbeatRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Main.EpfdInternalHeartbeatReply do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule Main.EpfdSuspect do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :process, 1, type: Main.ProcessId
end

defmodule Main.EpfdRestore do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :process, 1, type: Main.ProcessId
end

defmodule Main.PlSend do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :destination, 1, type: Main.ProcessId
  field :message, 2, type: Main.Message
end

defmodule Main.PlDeliver do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :sender, 1, type: Main.ProcessId
  field :message, 2, type: Main.Message
end

defmodule Main.NetworkMessage do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :senderHost, 1, type: :string
  field :senderListeningPort, 2, type: :int32
  field :message, 3, type: Main.Message
end

defmodule Main.Message do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :type, 1, type: Main.Message.Type, enum: true
  field :messageUuid, 2, type: :string
  field :FromAbstractionId, 3, type: :string
  field :ToAbstractionId, 4, type: :string
  field :systemId, 5, type: :string
  field :networkMessage, 6, type: Main.NetworkMessage
  field :procRegistration, 7, type: Main.ProcRegistration
  field :procInitializeSystem, 8, type: Main.ProcInitializeSystem
  field :procDestroySystem, 9, type: Main.ProcDestroySystem
  field :appBroadcast, 10, type: Main.AppBroadcast
  field :appValue, 11, type: Main.AppValue
  field :appPropose, 12, type: Main.AppPropose
  field :appDecide, 13, type: Main.AppDecide
  field :appRead, 14, type: Main.AppRead
  field :appWrite, 15, type: Main.AppWrite
  field :appReadReturn, 16, type: Main.AppReadReturn
  field :appWriteReturn, 17, type: Main.AppWriteReturn
  field :ucDecide, 20, type: Main.UcDecide
  field :ucPropose, 21, type: Main.UcPropose
  field :epAbort, 30, type: Main.EpAbort
  field :epAborted, 31, type: Main.EpAborted
  field :epInternalAccept, 32, type: Main.EpInternalAccept
  field :epDecide, 33, type: Main.EpDecide
  field :epInternalDecided, 34, type: Main.EpInternalDecided
  field :epPropose, 35, type: Main.EpPropose
  field :epInternalRead, 36, type: Main.EpInternalRead
  field :epInternalState, 37, type: Main.EpInternalState
  field :epInternalWrite, 38, type: Main.EpInternalWrite
  field :ecInternalNack, 41, type: Main.EcInternalNack
  field :ecInternalNewEpoch, 42, type: Main.EcInternalNewEpoch
  field :ecStartEpoch, 43, type: Main.EcStartEpoch
  field :bebBroadcast, 50, type: Main.BebBroadcast
  field :bebDeliver, 51, type: Main.BebDeliver
  field :eldTimeout, 60, type: Main.EldTimeout
  field :eldTrust, 61, type: Main.EldTrust
  field :nnarInternalAck, 70, type: Main.NnarInternalAck
  field :nnarInternalRead, 71, type: Main.NnarInternalRead
  field :nnarInternalValue, 72, type: Main.NnarInternalValue
  field :nnarInternalWrite, 73, type: Main.NnarInternalWrite
  field :nnarRead, 74, type: Main.NnarRead
  field :nnarReadReturn, 75, type: Main.NnarReadReturn
  field :nnarWrite, 76, type: Main.NnarWrite
  field :nnarWriteReturn, 77, type: Main.NnarWriteReturn
  field :epfdTimeout, 80, type: Main.EpfdTimeout
  field :epfdInternalHeartbeatRequest, 81, type: Main.EpfdInternalHeartbeatRequest
  field :epfdInternalHeartbeatReply, 82, type: Main.EpfdInternalHeartbeatReply
  field :epfdSuspect, 83, type: Main.EpfdSuspect
  field :epfdRestore, 84, type: Main.EpfdRestore
  field :plDeliver, 90, type: Main.PlDeliver
  field :plSend, 91, type: Main.PlSend
end