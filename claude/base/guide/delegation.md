# Delegation

The Agent tool sets a subagent's effort only where instructions ask for it, and runs the subagent on the parent's model unless the call names one, so this topic is the instruction that sets both. It decides when a subagent is launched and what it is launched as; Communication decides how its results reach me.

- **A subagent's agent type, model, and effort follow its role.** The call names `subagent_type`, `model`, and `effort` wherever the table gives them, and names neither `model` nor `effort` where the table says inherited, so the subagent takes the parent's.

  | Role | `subagent_type` | `model` | `effort` |
  |---|---|---|---|
  | Implementing a settled plan step | `general-purpose` | `opus` | `high` |
  | Reviewing or verifying code | `general-purpose` | `opus` | `xhigh` |
  | Searching and reading only | `Explore` | inherited | inherited |
  | Everything else | chosen per call | inherited | inherited |

- **Implementation runs at `high`.** The plan step and this guide carry the judgment there, so the agent spends less of its own. It runs at `high` rather than `medium` because it still writes code held to this guide, and it steps down only once a measurement of cost and quality per completed task shows no loss.
- **Review runs at `xhigh`.** A review's whole output is judgment, which is what effort buys.
- **A lookup that only searches and reads is an `Explore` agent.** It starts with a fraction of a general-purpose agent's context and holds no tool that edits or writes, so a lookup that turns into a change is relaunched as `general-purpose` under the role the change plays.
- **Delegate a bounded job whose reading the parent does not need.** A subagent starts from its own instructions, which for a general-purpose agent are every instruction file the parent loaded, and re-reads each file it touches, so it pays where it keeps the parent's context from growing by more than that start and the parent needs only the result: a plan step, a search, a review, a question to research. A step whose files the parent has already read and whose result is a few lines is done in the parent.
- **One job per launch, and the job ends with its step.** A delegated job is one plan step, one question, or one review, and the subagent reports once that job is done rather than carrying on into the next; the parent launches a fresh subagent for the next step, so no worker accumulates context across steps.
- **The parent holds plans and reports, never the workers' reading.** A dispatching parent's context grows by what its subagents hand back, so each prompt names what comes back and bounds its length, and never asks for file contents for the parent to read.
- **Review runs once per plan and once per finished change, never once per step.**
