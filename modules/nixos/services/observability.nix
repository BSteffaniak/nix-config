{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.myConfig.services.observability = {
    enable = mkEnableOption "Observability stack (Grafana, Prometheus, Loki, Tempo)";
  };

  config = mkIf config.myConfig.services.observability.enable {
    networking.firewall.allowedTCPPorts = [
      config.services.grafana.settings.server.http_port
    ];

    services.grafana = {
      enable = true;
      settings = {
        analytics.reporting_enabled = false;
        server = {
          http_port = 2342;
          http_addr = "0.0.0.0";
        };
      };

      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:${toString config.services.prometheus.port}";
          }
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
          }
          {
            name = "Tempo";
            type = "tempo";
            access = "proxy";
            url = "http://127.0.0.1:${toString config.services.tempo.settings.server.http_listen_port}";
          }
        ];
      };
    };

    services.tempo = {
      enable = true;
      settings = {
        server = {
          http_listen_port = 9005;
          http_listen_address = "127.0.0.1";
          grpc_listen_port = 9006;
          grpc_listen_address = "127.0.0.1";
        };
        ingester = {
          max_block_duration = "10m";
        };
        compactor = {
          compaction = {
            block_retention = "24h";
          };
        };

        distributor = {
          receivers = {
            otlp = {
              protocols = {
                http = {
                  endpoint = "0.0.0.0:4318";
                };
                grpc = {
                  endpoint = "0.0.0.0:4317";
                };
              };
            };
          };
        };

        metrics_generator = {
          registry = {
            external_labels = {
              source = "tempo";
              cluster = "docker-compose";
            };
          };
          storage = {
            path = "/tmp/tempo/generator/wal";
            remote_write = [
              {
                url = "http://127.0.0.1:${toString config.services.prometheus.port}/api/v1/write";
                send_exemplars = true;
              }
            ];
          };
        };
        storage = {
          trace = {
            backend = "local";
            wal = {
              path = "/tmp/tempo/wal";
            };
            local = {
              path = "/tmp/tempo/blocks";
            };
          };
        };
      };
    };

    services.prometheus = {
      enable = true;
      port = 9001;
      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          port = 9002;
        };
      };
      scrapeConfigs = [
        {
          scrape_interval = "2s";
          job_name = config.myConfig.username;
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
            }
          ];
        }
        {
          scrape_interval = "2s";
          job_name = "moosicbox_server";
          static_configs = [
            {
              targets = [ "127.0.0.1:8000" ];
            }
          ];
        }
      ];
    };

    services.loki = {
      enable = true;
      configuration = {
        server.http_listen_port = 28183;
        auth_enabled = false;

        ingester = {
          lifecycler = {
            address = "127.0.0.1";
            ring = {
              kvstore = {
                store = "inmemory";
              };
              replication_factor = 1;
            };
          };
          chunk_idle_period = "1h";
          max_chunk_age = "1h";
          chunk_target_size = 999999;
          chunk_retain_period = "30s";
        };

        schema_config = {
          configs = [
            {
              from = "2022-06-06";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
        };

        storage_config = {
          tsdb_shipper = {
            active_index_directory = "/var/lib/loki/tsdb-active";
            cache_location = "/var/lib/loki/tsdb-cache";
            cache_ttl = "24h";
          };

          filesystem = {
            directory = "/var/lib/loki/chunks";
          };
        };

        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };

        table_manager = {
          retention_deletes_enabled = false;
          retention_period = "0s";
        };

        compactor = {
          working_directory = "/var/lib/loki";
          compactor_ring = {
            kvstore = {
              store = "inmemory";
            };
          };
        };
      };
    };

    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 3031;
          grpc_listen_port = 0;
        };
        positions = {
          filename = "/tmp/positions.yaml";
        };
        clients = [
          {
            url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}/loki/api/v1/push";
          }
        ];
        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = config.myConfig.username;
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
            ];
          }
        ];
      };
    };
  };
}
