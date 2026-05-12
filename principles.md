# Migration principles

1. Jail definitions should be localized, e.g. jails/ingress.yml. A jail definition should define zfs mounts, nullfs mounts, files to install, networking scripts (pre_start etc) to insert into jail.conf.
2. Jails should be defined as hosts in the inventory file. To reach them, ansible should use a ssh conn to the host and then `jexec $jailname`.
3. Each structure in the jail definition yml (e.g. `pkg: ["nginx"]`) should be handled by an ansible role that activates when a relevant structure is defined in the jail definition.
4. Both the host (pursotin) and the jails inside it should be defined in this project, so ansible should be configured to use correct hosts and correct connection methods depending on host.
5. The main playbooks should be very light and just dispatch.
