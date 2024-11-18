# frozen_string_literal: true
# 如果需要保护直传,就需要继承这个Controller,并且我们需要关闭默认的路由
# Creates a new blob on the server side in anticipation of a direct-to-service upload from the client side.
# When the client-side upload is completed, the signed_blob_id can be submitted as part of the form to reference
# the blob that was created up front.
class ActiveStorage::DirectUploadsController < ActiveStorage::BaseController
  def create
    blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_args) #保存上传文件的元信息
    render json: direct_upload_json(blob)
  end

  private
    def blob_args
      params.expect(blob: [:filename, :byte_size, :checksum, :content_type, metadata: {}]).to_h.symbolize_keys
    end

    def direct_upload_json(blob) #生成对应的云存储信息
      blob.as_json(root: false, methods: :signed_id).merge(direct_upload: {
        url: blob.service_url_for_direct_upload,
        headers: blob.service_headers_for_direct_upload
      })
    end
end
