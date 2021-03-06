#
# Cookbook Name:: couchbase
# Provider:: cluster
#

use_inline_resources

def command(action, ip="127.0.0.1", port=8091)
  cmd = couchbase_cli_command(action, new_resource.install_path)
  cmd = couchbase_cli_cluster(cmd, ip, port, new_resource.username, new_resource.password)

  return cmd
end

def init_or_edit
  action = 'cluster-init'
  action = 'cluster-edit' if check_cluster(new_resource.username, new_resource.password, "127.0.0.1:#{new_resource.port}")

  cmd = command(action)
  cmd = couchbase_cli_cluster_username(cmd, new_resource.username)
  cmd = couchbase_cli_cluster_password(cmd, new_resource.password)
  cmd = couchbase_cli_cluster_ramsize(cmd, new_resource.ramsize)
  cmd = couchbase_cli_cluster_index_ramsize(cmd, new_resource.index_ramsize)
  cmd = couchbase_cli_services(cmd, new_resource.services)

  execute "set cluster configuration #{cmd}" do
    command cmd
  end
end

action :rebalance do
  cmd = command('rebalance', new_resource.cluster_ip)

  execute "rebalancing cluster with #{cmd}" do
    command cmd
  end
end

action :init do
    init_or_edit
end

action :edit do
    init_or_edit
end

action :join do
  Chef::Log.info "Trying to join cluster #{new_resource.cluster_ip}"

  unless check_in_cluster(new_resource.username, new_resource.password, new_resource.ip, new_resource.cluster_ip, new_resource.port)
    unless new_resource.ip == new_resource.cluster_ip
      Chef::Log.info "#{new_resource.cluster_ip} is not the current instance"

      cmd = command('server-add', new_resource.cluster_ip)
      cmd = couchbase_cli_server_add(cmd, new_resource.ip, new_resource.port, new_resource.username, new_resource.password)
      cmd = couchbase_cli_services(cmd, new_resource.services)

      execute "joining to cluster with #{cmd}" do
        command cmd
        ignore_failure true
      end
    end
  else
    Chef::Log.info "Instance is already member of cluster #{new_resource.cluster_ip}"
  end

  couchbase_cluster "default" do
    install_path new_resource.install_path
    cluster_ip   new_resource.cluster_ip
    username     new_resource.username
    password     new_resource.password
    action       :rebalance
  end
end

action :leave do
  if check_cluster(new_resource.username, new_resource.password, "127.0.0.1:#{new_resource.port}")
    infos = get_node_info(new_resource.username, new_resource.password, "127.0.0.1", new_resource.port)

    node = infos['nodes'].bsearch { |n| !n["thisNode"] }

    if !node.nil?
#      cmdFailover = command('failover', node["hostname"], nil)
#      cmdFailover = couchbase_cli_server_failover(cmdFailover, new_resource.ip, new_resource.port)

      cmdRebalance = command('rebalance', node["hostname"], nil)
      cmdRebalance = couchbase_cli_server_remove(cmdRebalance, new_resource.ip, new_resource.port)

#      execute "failing over server with #{cmdFailover}" do
#        command cmdFailover
#      end

      execute "leaving cluster with #{cmdRebalance}" do
        command cmdRebalance
      end
    end
  end
end
