require 'master_manipulator'
require 'lvm_helper'
require 'securerandom'

test_name "FM-4969 - C97372 - create logical volume with parameter min 'range'"

# initilize
pv = 'hdisk1'
vg = 'VG_' + SecureRandom.hex(2)
lv = 'LV_' + SecureRandom.hex(3)

# Teardown
teardown do
  confine_block(:except, roles: ['master', 'dashboard', 'database']) do
    agents.each do |agent|
      remove_all(agent, pv, vg, lv, aix = true)
    end
  end
end

pp = <<-MANIFEST
volume_group {'#{vg}':
  ensure            => present,
  physical_volumes  => #{pv}
}
->
logical_volume{'#{lv}':
  ensure        => present,
  volume_group  => '#{vg}',
  initial_size  => '20M',
  range         => 'minimum',
}
MANIFEST

step 'Inject "site.pp" on Master'
site_pp = create_site_pp(master, manifest: pp)
inject_site_pp(master, get_site_pp_path(master), site_pp)

step 'Run Puppet Agent to create logical volumes'
confine_block(:except, roles: ['master', 'dashboard', 'database']) do
  agents.each do |agent|
    on(agent, '/opt/puppetlabs/puppet/bin/puppet agent -t --environment production', acceptable_exit_codes: [0, 2]) do |result|
      assert_no_match(%r{Error:}, result.stderr, 'Unexpected error was detected!')
    end

    step "Verify the logical volume with param minimum is created: #{lv}"
    verify_if_created?(agent, 'aix_logical_volume', lv, vg, "INTER-POLICY:\s+minimum")
  end
end
