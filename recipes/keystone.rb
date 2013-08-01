# Cookbook Name:: openstack-monitoring
# Recipe:: keystone
#
# Copyright 2013, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
include_recipe "monitoring"

# Keystone monitoring setup..
if node.recipe?("keystone::keystone-api")
  platform_options = node["keystone"]["platform"]
  ks_service_endpoint = get_access_endpoint("keystone-api", "keystone", "service-api")

  ks_real_service_endpoint = get_realserver_endpoints("keystone-api", "keystone", "service-api")[0]
  ks_real_admin_endpoint = get_realserver_endpoints("keystone-api", "keystone", "admin-api")[0]

  unless ks_service_endpoint["scheme"] == "https"
    monitoring_procmon "keystone" do
      procname=platform_options["keystone_service"]
      sname=platform_options["keystone_process_name"]
      process_name sname
      script_name procname
      rules [
              "if failed host #{ks_real_service_endpoint['host']} port #{ks_real_service_endpoint['port']} protocol HTTP then restart",
              "if failed host #{ks_real_admin_endpoint['host']} port #{ks_real_admin_endpoint['port']} protocol HTTP then restart",
              "if 5 restarts within 5 cycles then timeout"
      ]
    end
  end

  monitoring_metric "keystone-proc" do
    type "proc"
    proc_name "keystone"
    proc_regex platform_options["keystone_service"]
    alarms(:failure_min => 2.0)
  end

  monitoring_metric "keystone" do
    keystone_admin_user = node["keystone"]["admin_user"]
    type "pyscript"
    script "keystone_plugin.py"
    options(
      "Username" => keystone_admin_user,
      "Password" => node["keystone"]["users"][keystone_admin_user]["password"],
      "TenantName" => node["keystone"]["users"][keystone_admin_user]["default_tenant"],
      "AuthURL" => ks_service_endpoint["uri"]
    )
  end
end
