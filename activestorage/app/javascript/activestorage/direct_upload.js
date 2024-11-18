import { FileChecksum } from "./file_checksum"
import { BlobRecord } from "./blob_record"
import { BlobUpload } from "./blob_upload"

let id = 0

export class DirectUpload {
  constructor(file, url, delegate, customHeaders = {}) {
    this.id = ++id
    this.file = file
    this.url = url
    this.delegate = delegate
    this.customHeaders = customHeaders
  }

  create(callback) {
    FileChecksum.create(this.file, (error, checksum) => {
      if (error) {
        callback(error)
        return
      }
      //先在后台创建上传记录，结果更新到blob.directUploadData字段中，在这个过程中，后台会生成一个URL
      const blob = new BlobRecord(this.file, checksum, this.url, this.customHeaders)
      notify(this.delegate, "directUploadWillCreateBlobWithXHR", blob.xhr)

      blob.create(error => {
        if (error) {
          callback(error)
        } else {
          const upload = new BlobUpload(blob) //上传全新的blob到云服务中
          notify(this.delegate, "directUploadWillStoreFileWithXHR", upload.xhr)
          upload.create(error => {
            if (error) {
              callback(error)
            } else {
              callback(null, blob.toJSON())
            }
          })
        }
      })
    })
  }
}

function notify(object, methodName, ...messages) {
  if (object && typeof object[methodName] == "function") {
    return object[methodName](...messages)
  }
}
