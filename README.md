# Algorithms, models and concepts in distributed systems
Coursework for the AMCDS subject.

## Notes

### Abstract API notions used in the book

```
	  |                           ^
 Request  |                           |  Indication
	  V                           |
	---------------------------------
	|send                    deliver|
	|                               |
	|                               |
	|            Layer n            |
	|                               |
	|invoke                  receive|
	---------------------------------
	  |                           ^
 Request  |                           |  Indication
	  V                           |
```


### Types of distributed algorithms

1. fail-stop algorithms, designed under the assumption that processes can fail by crashing but the crashes can be reliably detected by all the other processes;

2. fail-silent algorithms, where process crashes can never be reliably detected;

3. fail-noisy algorithms, where processes can fail by crashing and the crashes can be detected, but not always in an accurate manner (accuracy is only eventual);

4. fail-recovery algorithms, where processes can crash and later recover and still participate in the algorithm;

5. fail-arbitrary algorithms, where processes can deviate arbitrarily from the protocol specification and act in malicious, adversarial ways; and

6. randomized algorithms, where in addition to the classes presented so far, processes may make probabilistic choices by using a source of randomness.

### Types of processes

1. faulty process &rarr; a process that stops executing computations at a specific time t

2. correct process &rarr; a process which never crashes and executes an infinite number of steps 

### Types of faults 

1. Crashes &rarr; occurs when a process stops executing computations after a time t
2. Ommisions &rarr; occurs when a process does not send a message that is supposed to send 
3. Crashes with recoveries &rarr; occurs when a process crashes and stops but recovers later
4. Eavesdropping faults &rarr; occur when a process leaks information obtained in an algorithm by an outside entity and can be prevented by cryptography (encrypting communication messages and stored data)
5. Arbitrary faults &rarr; occur when a process deviates in any conceivable way from the algorithm assigned to it (the most general fault behaviour, is synonymous with the term "byzantine" referring to the byzantine problem)

### Types of links 
1. fair-loss links &rarr; capture the basic idea that messages might be lost but the probability for a message not to be lost is non-zero (weakest variant)

```
Module:
	Name: FairLossPointToPointLinks, instance fll.

Events:
	Request: <fll, Send | q, m>: Requests to send message m to process q.
	Indication: <fll, Deliver | p, m>: Delivers message m sent by process p.

Properties:
	FLL1: Fair-loss: If a correct process p infinitely often sends a message m to a correct process q, then q delivers m an infinite number of times.
	FLL2: Finite duplication: If a correct process p sends a message m a finite number of times to process q, then m cannot be delivered an infinite number of times by q.
	FLL3: No creation: If some process q delivers a message m with sender p, then m was previously sent to q by process p
```

2. stubborn links &rarr; links that hide the lower-layer retransmission mechanisms used by the sender process, when using fair-loss links, to make sure its messages are eventually delivered (received) by the destination process

```
Module:
	Name: StubbornPointToPointLinks, instance sl.

Events:
	Request: <sl, Send | q, m>: Requests to send message m to process q.
	Indication: <sl, Deliver | p, m>: Delivers message m sent by process p.

Properties:
	SL1: Stubborn delivery: If a correct process p sends a message m once to a correct process q, then q delivers m an infinite number of times.
	SL2: No creation: If some process q delivers a message m with sender p, then m was previously sent to q by process p
```

:exclamation: see page 35-36 for the "Retransmit Forever" algorithm containing an implementation of a stubborn link over a fair-loss link

3. perfect links &rarr; links containing both message duplicates detection and mechanisms for message retransmission (also called the reliable links abstraction)

```
Module:
	Name: PerfectPointToPointLinks, instance pl.

Events:
	Request: <pl, Send | q, m>: Requests to send message m to process q.
	Indication: <pl, Deliver | p, m>: Delivers message m sent by process p.

Properties:
		PL1: Reliable delivery: If a correct process p sends a message m to a correct process q, then q eventually delivers m.
		PL2: No duplication: No message is delivered by a process more than once.
		PL3: No creation: If some process q delivers a message m with sender p, then m was previously sent to q by process p.
```

:exclamation: see page 38 for the "Eliminate Duplicates" algorithm containing an implementation of a perfect point-to-point link instance 

### Failure detection
- provides information about which processes have crashed and which are correct, with this information not being necessarily accurate (not very useful against Byzantine faults) 

1. Perfect Failure Detection

```
Module:
	Name: PerfectFailureDetector, instance P. 
Events:
	Indication: ⟨ P, Crash | p ⟩: Detects that process p has crashed. 
Properties:
	PFD1: Strong completeness: Eventually, every process that crashes is permanently detected by every correct process.
	PFD2: Strong accuracy: If a process p is detected by any process, then p has crashed.
```

:exclamation: see page 51 for the "Exclude On Timeout" algorithm containing an implementation of a perfect failure detector 

2. Leader election
- useful when instead of detecting each failed process, we have to identify one process that has not failed
- can only be formulated for crash-stop process abstractions

```
Module:
	Name: LeaderElection, instance le. 

Events:
	Indication: ⟨ le, Leader | p ⟩: Indicates that process p is elected as leader. 

Properties:
	LE1: Eventual detection: Either there is no correct process, or some correct process is eventually elected as the leader.
	LE2: Accuracy: If a process is leader, then all previously elected leaders have crashed.
```

:exclamation: see page 53 for the "Monarchical Leader Election" algorithm containing an implementation of a leader election abstraction assuming a perfect failure detector

3. Eventually Perfect Failure Detector
- keeps track of processes that are "suspected" to have failed (instead of tracking failed processes)
- uses a timeout
- p increases its delay if it eventually receives a message from the "suspected" process q 

```
Module:
	Name: EventuallyPerfectFailureDetector, instance QP. 

Events:
	Indication: ⟨ QP , Suspect | p ⟩: Notifies that process p is suspected to have crashed.
	Indication: ⟨ QP, Restore | p ⟩: Notifies that process p is not suspected anymore. 

Properties:
	EPFD1: Strong completeness: Eventually, every process that crashes is perma- nently suspected by every correct process.
	EPFD2: Eventual strong accuracy: Eventually, no correct process is suspected by any correct process.
```

### Reliable broadcast

```
Module:
		Name: ReliableBroadcast, instance rb.

Events:
		Request: <rb, Broadcast | m>: Broadcasts a message m to all processes.
		Indication: <rb, Deliver | p, m>: Delivers a message m broadcast by process p.

Properties:
		RB1: Validity: If a correct process p broadcasts a message m, then p eventually delivers m.
		RB2: No duplication: No message is delivered more than once.
		RB3: No creation: If a process delivers a message m with sender s, then m was previously broadcast by process s.
		RB4: Agreement: If a message m is delivered by some correct process, then m is eventually delivered by every correct process.
```

eexclamation: see page 78 for the "Fail-stop" algorithm 

### Resilience
- the relation between the number f of potentially faulty processes and the total number N of processes in the system


## Resources

- [Introduction to Reliable and Secure Distributed Programming - Christian Cachin, Rachid Guerraoui, Luís Rodrigues](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&ved=2ahUKEwiB06H688L9AhVriv0HHd5QCNQQFnoECAgQAQ&url=https%3A%2F%2Fa8779-2401331.cluster15.canvas-user-content.com%2Fcourses%2F8779~17212%2Ffiles%2F8779~2401331%2Fcourse%2520files%2FIntroduction%2520to%2520Reliable%2520and%2520Secure%2520Distributed%2520Second%2520Edition%25202.pdf%3Fdownload_frd%3D1&usg=AOvVaw0ojQGVoV5Cz7TnFPEkx0z2)

- [Elixir - concurrency](https://manzanit0.github.io/elixir/2019/09/29/elixir-concurrency.html)

- [Cooperative vs. preemptive scheduling](https://stackoverflow.com/questions/55703365/what-is-the-difference-between-cooperative-multitasking-and-preemptive-multitask)

- [What are protocol buffers?](https://medium.com/javarevisited/what-are-protocol-buffers-and-why-they-are-widely-used-cbcb04d378b6)

- [elixir-protobuf](https://github.com/elixir-protobuf/protobuf)
