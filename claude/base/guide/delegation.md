# Delegation

The Agent tool sets a subagent's effort only where instructions ask for it, and runs the subagent on the parent's model unless the call names one, so this topic is the instruction that sets both. It decides what a subagent is launched as; Communication decides how its results reach me.

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
