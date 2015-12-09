module ThreeScale
  module Backend
    module Stats

      # This class manages the buckets where we are storing stats keys.
      # The way those buckets work is as follows: we are creating a bucket
      # every few seconds (10 by default now), and in each of those buckets,
      # we store all the stats keys that have changed in that bucket creation
      # interval.
      # The values of the keys that are stored in the buckets can be retrieved
      # with a normal call to redis.
      #
      # Currently, the Aggregator class is responsible for creating the
      # buckets, but we would like to change that in a future refactoring.
      class BucketStorage
        EVENTS_SLICE_CALL_TO_REDIS = 200
        private_constant :EVENTS_SLICE_CALL_TO_REDIS

        def initialize(storage)
          @storage = storage
        end

        def create_bucket(bucket)
          storage.zadd(Keys.changed_keys_key, bucket, bucket)
        end

        def delete_bucket(bucket)
          storage.zrem(Keys.changed_keys_key, bucket)
        end

        def all_buckets
          storage.zrange(Keys.changed_keys_key, 0, -1)
        end

        def put_in_bucket(event_key, bucket)
          return false unless exists?(bucket)
          storage.sadd(Keys.changed_keys_bucket_key(bucket), event_key)
        end

        # This function returns a Hash with the keys that are present in the
        # bucket and their values
        def bucket_content_with_values(bucket)
          event_keys = bucket_content(bucket)
          event_keys_slices =  event_keys.each_slice(EVENTS_SLICE_CALL_TO_REDIS)

          event_values = event_keys_slices.flat_map do |event_keys_slice|
            storage.mget(event_keys_slice)
          end

          Hash[event_keys.zip(event_values)]
        end

        private

        attr_reader :storage

        def exists?(bucket)
          all_buckets.include?(bucket)
        end

        def bucket_content(bucket)
          storage.smembers(Keys.changed_keys_bucket_key(bucket))
        end
      end
    end
  end
end
