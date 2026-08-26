class AddBatchesToSolidQueue < ActiveRecord::Migration[7.1]
  def change
    add_column table_for(:jobs), :batch_id, :bigint, if_not_exists: true
    add_index table_for(:jobs), :batch_id, if_not_exists: true

    create_table table_for(:batches), if_not_exists: true do |t|
      t.string :active_job_batch_id
      t.string :description
      t.text :on_finish
      t.text :on_success
      t.text :on_failure
      t.text :metadata
      t.integer :total_jobs, default: 0, null: false
      t.integer :completed_jobs, default: 0, null: false
      t.integer :failed_jobs, default: 0, null: false
      t.datetime :enqueued_at
      t.datetime :finished_at
      t.datetime :failed_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.index :active_job_batch_id, unique: true
      t.index :finished_at
    end

    create_table table_for(:batch_executions), if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.bigint :batch_id, null: false
      t.datetime :created_at, null: false

      t.index :job_id, unique: true
      t.index :batch_id
      t.foreign_key table_for(:batches), column: :batch_id, on_delete: :cascade
      t.foreign_key table_for(:jobs), column: :job_id, on_delete: :cascade
    end
  end

  private

  def prefix
    SolidQueue.table_name_prefix
  end

  def table_for(name)
    "#{prefix}#{name}"
  end
end
