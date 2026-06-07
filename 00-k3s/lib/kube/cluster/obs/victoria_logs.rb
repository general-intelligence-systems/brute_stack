# frozen_string_literal: true

# Schema registration for VictoriaMetrics and Perses operator CRDs.
# Requiring this file makes Kube::Cluster['VLSingle'], Kube::Cluster['VMSingle'],
# Kube::Cluster['VMAgent'], Kube::Cluster['VMNodeScrape'], Kube::Cluster['VMServiceScrape'],
# Kube::Cluster['VLAgent'], Kube::Cluster['Perses'], Kube::Cluster['PersesDatasource'],
# etc. available as typed resources.

module Kube
  module Cluster
    module Obs
      VictoriaMetricsChart =
        Kube::Helm::Repo
          .new('victoria-metrics-operator', url: 'oci://ghcr.io/victoriametrics/helm-charts')
          .fetch('victoria-metrics-operator', version: '0.62.1')

      VictoriaMetricsChart.crds.each do |crd|
        crd.to_json_schema.then do |s|
          Kube::Schema.register(
            s[:kind],
            schema: s[:schema],
            api_version: s[:api_version]
          )
        end
      end

      PersesChart =
        Kube::Helm::Repo
          .new('perses', url: 'https://perses.github.io/helm-charts')
          .fetch('perses-operator', version: '0.4.0')

      PersesChart.apply_values({}).select { |r|
        r.kind == 'CustomResourceDefinition'
      }.each do |crd|
        Kube::Cluster['CustomResourceDefinition'].new(crd.to_h).to_json_schema.then do |s|
          Kube::Schema.register(
            s[:kind],
            schema: s[:schema],
            api_version: s[:api_version]
          )
        end
      end
    end
  end
end
