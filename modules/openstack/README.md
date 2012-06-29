
# OpenStack Puppet Module

This module implements puppet definitions for managing OpenStack nodes.


# TODO

- nova-network HA awareness (via corosync/pacemaker, 2-node cluster)
  - ideally still keeping the ability to run nova-network in standalone
- define project quotas (including number of SGs)
- ability to define SGs for any project, not just the main project.

# Glusterfs Integration

    gluster volume create nova-instances replica 3 transport tcp,rdma colossus{09,10,11,12}:/srv/nova-instances
    gluster volume start nova-instances
    mount -t glsuterfs colossus09:/srv/nova-instances /var/lib/nova/instances
